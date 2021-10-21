`#!/usr/bin/env node
`
import parseArgs from 'minimist'
import pathlib from 'path'
import fs from 'fs'
import chokidar from 'chokidar'         # file watcher

import {assert, undef, croak, words, sep_eq} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, withExt, mkpath, forEachFile, newerDestFileExists,
	shortenPath,
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

dirRoot = undef
doWatch = true         # turn off with -n
envOnly = false        # set with -e
debugStarbucks = false # set with -D
readySeen = false      # set true when 'ready' event is seen

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	log "DIR_ROOT: #{dirRoot}"

	loadPrivEnvFrom(dirRoot)
	logPrivEnv()
	if envOnly
		process.exit()

	watcher = chokidar.watch(dirRoot, {
		persistent: doWatch,
		})

	watcher.on 'all', (event, path) ->

		if event == 'ready'
			readySeen = true
			if doWatch
				log "...watching for further file changes"
			else
				log "...not watching for further file changes"
			return

		if path.match(/node_modules/)
			return

		if lMatches = path.match(/\.(?:cielo|coffee|starbucks|taml)$/)
			log "#{event} #{shortenPath(path)}"
			ext = lMatches[0]
			if event == 'unlink'
				unlinkRelatedFiles(path, ext)
			else
				switch ext
					when '.cielo'
						brewCieloFile(path)
					when '.coffee'
						brewCoffeeFile(path)
					when '.starbucks'
						brewStarbucksFile(path)
					when '.taml'
						brewTamlFile(path)
					else
						croak "Invalid file extension: '#{ext}'"
		return

	return

# ---------------------------------------------------------------------------

unlinkRelatedFiles = (path, ext) ->
	# --- file 'path' was removed

	switch ext
		when '.cielo'
			removeFile(path, '.coffee')
		when '.coffee', '.taml'
			if path.indexOf('_') == -1
				removeFile(path, '.js')
			else
				removeFile(path.replace('_',''), '.js')
		when '.starbucks'
			if path.indexOf('_') == -1
				removeFile(path, '.svelte')
			else
				removeFile(path.replace('_',''), '.svelte')
		else
			croak "Invalid file extension: '#{ext}'"
	return

# ---------------------------------------------------------------------------

removeFile = (path, ext) ->
	# --- file 'path' was removed
	#     remove same file, but with ext 'ext'

	fullpath = withExt(path, ext)
	try
		fs.unlinkSync fullpath
		log "   unlink #{filename}"
	return

# ---------------------------------------------------------------------------

brewCieloFile = (srcPath) ->
	# --- cielo => coffee

	destPath = withExt(srcPath, '.coffee')
	if newerDestFileExists(srcPath, destPath) && readySeen
		log "   dest exists"
		return
	coffeeCode = brewCielo(slurp(srcPath))
	output coffeeCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath) ->
	# --- coffee => js

	destPath = withExt(srcPath, '.js').replace('_', '')
	if newerDestFileExists(srcPath, destPath) && readySeen
		log "   dest exists"
		return
	jsCode = brewCoffee(slurp(srcPath))
	output jsCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (srcPath) ->

	destPath = withExt(srcPath, '.svelte').replace('_', '')
	if newerDestFileExists(srcPath, destPath) && readySeen
		log "   dest exists"
		return
	content = slurp(srcPath)
	if debugStarbucks
		log sep_eq
		log content
		log sep_eq

	hParsed = pathlib.parse(srcPath)
	hOptions = {
		content: content,
		filename: hParsed.base,
		}
	code = starbucks(hOptions).code
	if debugStarbucks
		log code
		log sep_eq
	output code, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewTamlFile = (srcPath) ->

	destPath = withExt(srcPath, '.js').replace('_', '')
	if newerDestFileExists(srcPath, destPath) && readySeen
		log "   dest exists"
		return
	hParsed = pathlib.parse(srcPath)
	srcDir = mkpath(hParsed.dir)
	envDir = hPrivEnv.DIR_STORES
	assert envDir, "DIR_STORES is not set!"
	if (srcDir != envDir)
		log "   #{srcDir} is not #{envDir}"
		return

	hInfo = pathlib.parse(destPath)
	stub = hInfo.name

	tamlCode = slurp(srcPath)
	output("""
		import {TAMLDataStore} from '@jdeighan/starbucks/stores';

		export let #{stub} = new TAMLDataStore(`#{tamlCode}`);
		""", srcPath, destPath)
	return

# ---------------------------------------------------------------------------

output = (code, srcPath, destPath) ->

	try
		barf destPath, code
	catch err
		log "ERROR: #{err.message}"
	log "   #{shortenPath(srcPath)} => #{shortenPath(destPath)}"
	return

# ---------------------------------------------------------------------------

parseCmdArgs = () ->

	# --- uses minimist
	hArgs = parseArgs(process.argv.slice(2), {
		boolean: words('h n e d D'),
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
		log "   -D dump input & output from starbucks conversions"
		log "<dir> defaults to current working directory"
		process.exit()

	if hArgs.n
		doWatch = false

	if hArgs.e
		envOnly = true

	if hArgs.d
		log "extensive debugging on"
		setDebugging true

	if hArgs.D
		log "debugging starbucks conversions"
		debugStarbucks = true

	if hArgs._?
		if hArgs._.length > 1
			croak "Only one directory path allowed"
		if hArgs._.length == 1
			dirRoot = mkpath(hArgs._[0])
		else if process.env.DIR_ROOT
			dirRoot = mkpath(process.env.DIR_ROOT)
		else
			dirRoot = process.env.DIR_ROOT = mkpath(process.cwd())
	return

# ---------------------------------------------------------------------------

main()
