`#!/usr/bin/env node
`
import {strict as assert} from 'assert'
import parseArgs from 'minimist'
import {parse as parsePath} from 'path'
import {existsSync, statSync, unlinkSync} from 'fs'
import chokidar from 'chokidar'         # file watcher

import {undef, croak, words} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, withExt, mkpath, forEachFile, newerDestFileExists,
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {hPrivEnv, logPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {loadPrivEnvFrom} from '@jdeighan/env'
import {isTAML, taml} from '@jdeighan/string-input/taml'
import {starbucks} from '@jdeighan/starbucks'
import {brewCielo, brewCoffee} from './brewCielo.js'

###
	cielo [-h | -n | -e | -d ]
###

doWatch = true      # turn off with -n
envOnly = false     # set with -e
dirRoot = undef
readySeen = false   # set true when 'ready' event is seen

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	if ! dirRoot?
		dirRoot = process.cwd()
	log "ROOT: #{dirRoot}"

	loadPrivEnvFrom(dirRoot)
	if envOnly
		log "DIR_ROOT = '#{dirRoot}'"
		logPrivEnv()
		process.exit()

	watcher = chokidar.watch(dirRoot, {
		persistent: doWatch,
		})

	watcher.on 'all', (event, path) ->

		if event == 'ready'
			readySeen = true
			return

		if path.match(/node_modules/) || (event == 'unlink')
			return

		if lMatches = path.match(/\.(cielo|coffee|starbucks|taml)$/)
			ext = lMatches[0]
			log "#{event} #{fixPath(path)}"
			if ext == '.cielo'
				brewCieloFile(path)
			else if ext == '.coffee'
				brewCoffeeFile(path)
			else if ext == '.starbucks'
				brewStarbucksFile(path)
			else if ext == '.taml'
				brewTamlFile(path)
				if readySeen
					rebuildTamlStores()
			else
				croak "Invalid file extension: '#{ext}'"

	if ! doWatch
		log "...not watching for further file changes"
	return

# ---------------------------------------------------------------------------

brewTamlFile = (srcPath) ->

	destPath = withExt(srcPath, '.js')
	if newerDestFileExists(srcPath, destPath)
		log "   dest exists"
		return
	hParsed = parsePath(srcPath)
	srcDir = mkpath(hParsed.dir)
	if (srcDir != hPrivEnv.DIR_STORES)
		log "   #{srcDir} is not #{hPrivEnv.DIR_STORES}"
		return

	tamlCode = slurp(srcPath)
	output("""
		import {TAMLDataStore} from '@jdeighan/starbucks/stores'
		oz = new TAMLDataStore(`#{tamlCode}`);
		""", srcPath, destPath)
	return

# ---------------------------------------------------------------------------

rebuildTamlStores = () ->

	dir = hPrivEnv.DIR_STORES
	tamlStoresPath = mkpath(dir, 'tamlStores.js')
	if existsSync(tamlStoresPath)
		unlinkSync tamlStoresPath

	lLines = []
	addLine = (filename, dir, level) ->
		if filename == 'tamlStores.js'
			return
		stub = filename.substr(0, filename.length - 3)
		lLines.push "import {#{stub}DataStore} from '#{filename}';"

	forEachFile(dir, addLine, /\.js$/)
	barf tamlStoresPath, lLines.join("\n") + "\n"
	return

# ---------------------------------------------------------------------------

brewCieloFile = (srcPath) ->
	# --- cielo => coffee

	destPath = withExt(srcPath, '.coffee')
	if newerDestFileExists(srcPath, destPath)
		log "   dest exists"
		return
	coffeeCode = brewCielo(slurp(srcPath))
	output coffeeCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath) ->
	# --- coffee => js

	destPath = withExt(srcPath, '.js')
	if newerDestFileExists(srcPath, destPath)
		log "   dest exists"
		return
	jsCode = brewCoffee(slurp(srcPath))
	output jsCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (srcPath) ->

	destPath = withExt(srcPath, '.svelte').replace('_', '')
	if newerDestFileExists(srcPath, destPath)
		log "   dest exists"
		return
	hParsed = parsePath(srcPath)
	hOptions = {
		content: slurp(srcPath),
		filename: hParsed.base,
		}
	code = starbucks(hOptions).code
	output code, srcPath, destPath
	return

# ---------------------------------------------------------------------------

output = (code, srcPath, destPath) ->

	barf destPath, code
	log "   #{fixPath(srcPath)} => #{fixPath(destPath)}"
	return

# ---------------------------------------------------------------------------

parseCmdArgs = () ->

	hArgs = parseArgs(process.argv.slice(2), {
		boolean: words('h n e d'),
		unknown: (opt) ->
			return true
		})

	# --- Handle request for help
	if hArgs.h
		log "cielo [ <dir> ]"
		log "   -h help"
		log "   -n process files, don't watch for changes"
		log "   -e just display custom environment variables"
		log "   -d turn on debugging (a lot of output!)"
		log "<dir> defaults to current working directory"
		process.exit()

	if hArgs.n
		doWatch = false

	if hArgs.e
		envOnly = true

	if hArgs.d
		log "extensive debugging on"
		setDebugging true

	if hArgs._?
		if hArgs._.length == 1
			dirRoot = hArgs._[0]
		else if hArgs._.length > 1
			croak "Only one directory path allowed"
	return

# ---------------------------------------------------------------------------

fixPath = (path) ->
	# --- Replace user's home dir with '~'

	str = mkpath(path)
	if lMatches = str.match(///^
			c:/Users/[a-z_][a-z0-9_]*/(.*)
			$///i)
		[_, tail] = lMatches
		return "~/#{tail}"
	else
		return str

# ---------------------------------------------------------------------------

main()
