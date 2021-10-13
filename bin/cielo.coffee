`#!/usr/bin/env node
`
import {strict as assert} from 'assert'
import parseArgs from 'minimist'
import {parse as parsePath} from 'path'
import chokidar from 'chokidar'         # file watcher

import {undef, croak, words} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, withExt, mkpath,
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {hPrivEnv, logPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {loadPrivEnvFrom} from '@jdeighan/env'
import {starbucks} from '@jdeighan/starbucks'
import {brewCielo} from './brewCielo.js'

###
	cielo [-h | -n | -e | -d ]
###

doWatch = true      # turn off with -n
envOnly = false     # set with -e
dirRoot = undef
specialChar = '%'

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	if ! dirRoot?
		dirRoot = process.cwd()
	log "ROOT: #{dirRoot}"

	loadPrivEnvFrom(dirRoot)
	logPrivEnv()
	if envOnly
		process.exit()

	watcher = chokidar.watch(dirRoot, {
		persistent: doWatch,
		})

	watcher.on 'all', (event, path) ->

		if path.match(/node_modules/) || (event == 'unlink')
			return

		if lMatches = path.match(/\.(cielo|starbucks)$/)
			ext = lMatches[0]
			log "#{event} #{fixPath(path)}"
			if ext == '.cielo'
				brewCieloFile(path)
			else if ext == '.starbucks'
				brewStarbucksFile(path)
			else
				croak "Invalid file extension: '#{ext}'"

	if ! doWatch
		log "...not watching for further file changes"
	return

# ---------------------------------------------------------------------------

brewCieloFile = (path) ->

	[coffeeCode, jsCode] = brewCielo(slurp(path), 'both')
	output coffeeCode, path, '.coffee'
	output jsCode, path, '.js', true
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (path) ->

	hParsed = parsePath(path)
	hOptions = {
		content: slurp(path),
		filename: hParsed.base,
		}
	code = starbucks(hOptions).code
	output code, path, '.svelte', true
	return

# ---------------------------------------------------------------------------

output = (code, inpath, outExt, expose=false) ->

	outpath = withExt(inpath, outExt)
	if expose
		outpath = outpath.replace(specialChar, '').replace('_', '')
	barf outpath, code
	log "   #{fixPath(inpath)} => #{outExt}"
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
