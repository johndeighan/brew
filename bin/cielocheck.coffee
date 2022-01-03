`#!/usr/bin/env node
`
import parseArgs from 'minimist'
import pathlib from 'path'
import fs from 'fs'
import chokidar from 'chokidar'         # file watcher
import {exec} from 'child_process'

import {
	assert, undef, warn, croak, words, sep_eq, nonEmpty,
	isString, isArray,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, withExt, mkpath, forEachFile, newerDestFileExists,
	shortenPath, isFile, isDir, isSimpleFileName, getFullPath,
	fileExt
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {loadEnvFrom} from '@jdeighan/env'
import {getNeededSymbols} from '@jdeighan/string-input/coffee'
import {brewCieloFile} from '@jdeighan/string-input/cielo'
import {brewCoffee} from '@jdeighan/string-input/coffee'

dirRoot = undef        # set in parseCmdArgs()
lFiles = []            # to process individual files

# --- Default values for flags
doDebug = false        # set with -d
quiet   = false        # set with -q

nProcessed = 0

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	process.env.DIR_ROOT = dirRoot
	lEnvFiles = loadEnvFrom(dirRoot)
	checkDirs()

	if nonEmpty(lFiles)
		# --- Process only these files
		for path in lFiles
			if fileExt(path) == '.cielo'
				if ! quiet
					log "BREW #{shortenPath(path)}"

				# --- This creates the *.coffee file
				brewCieloFile path

		dumpStats()
		return   # --- DONE

	watcher = chokidar.watch(dirRoot, {
		persistent: false,
		})

	watcher.on 'ready', () ->

		if ! quiet
			dumpStats()

	watcher.on 'all', (event, path) ->

		# --- never process files in a node_modules directory
		#     or any directory whose name begins with '.'
		if path.match(/node_modules/) || path.match(/[\/\\]\./)
			return

		if fileExt(path) == '.cielo'
			if ! quiet
				log "#{event} #{shortenPath(path)}"
			if event != 'unlink'
				brewCieloFile path

	return

# ---------------------------------------------------------------------------

dumpOptions = () ->

	log "OPTIONS:"
	log "   doDebug = #{doDebug}"
	log "   quiet   = #{quiet}"
	return

# ---------------------------------------------------------------------------

parseCmdArgs = () ->

	# --- uses minimist
	hArgs = parseArgs(process.argv.slice(2), {
		boolean: words('h d q D'),
		unknown: (opt) ->
			return true
		})

	# --- Handle request for help
	if hArgs.h
		log "cielocheck { <dir> | <file> }"
		log "   -h help"
		log "   -d turn on some debugging"
		log "   -q quiet output (only errors)"
		log "   -D turn on debugging (a lot of output!)"
		log "<dir> defaults to current working directory"
		process.exit()

	doDebug = true if hArgs.d
	quiet   = true if hArgs.q

	if ! quiet
		dumpOptions()

	if hArgs.D
		setDebugging true

	if hArgs._?
		for path in hArgs._
			if path.indexOf('.') == 0
				# --- relative path - convert to absolute
				path = getFullPath(path)  # converts \ to /
			else
				path = mkpath(path)    # convert \ to /
			if isDir(path)
				assert ! dirRoot, "multiple dirs not allowed"
				dirRoot = path
				if ! quiet
					log "DIR_ROOT: #{dirRoot} (from cmd line)"
			else if isFile(path)
				lFiles.push path
			else
				croak "Invalid path '#{path}' on command line"

	if ! dirRoot
		dirRoot = mkpath(process.cwd())
		if ! quiet
			log "DIR_ROOT: #{dirRoot} (from cwd())"

	# --- set env var DIR_ROOT
	process.env.DIR_ROOT = dirRoot

	# --- Convert any simple file names in lFiles to full path
	for path in lFiles
		if isSimpleFileName(path)
			path = mkpath(dirRoot, path)

	return

# ---------------------------------------------------------------------------

checkDir = (key) ->

	dir = process.env[key]
	if dir && ! fs.existsSync(dir)
		if doDebug
			warn "directory #{key} '#{dir}' does not exist - removing"
		delete process.env[key]
	return

# ---------------------------------------------------------------------------

checkDirs = () ->

	for key of hPrivEnv
		if key.match(/^DIR_/)
			checkDir(key)
	return

# ---------------------------------------------------------------------------

main()
