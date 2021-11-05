`#!/usr/bin/env node
`
import parseArgs from 'minimist'
import pathlib from 'path'
import fs from 'fs'
import chokidar from 'chokidar'         # file watcher
import {exec} from 'child_process'

import {
	assert, undef, warn, croak, words, sep_eq, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, withExt, mkpath, forEachFile, newerDestFileExists,
	shortenPath, isFile, isDir, isSimpleFileName, getFullPath,
	fileExt
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {hPrivEnv, logPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {loadPrivEnvFrom} from '@jdeighan/env'
import {isTAML, taml} from '@jdeighan/string-input/taml'
import {starbucks} from '@jdeighan/starbucks'
import {brewCielo, brewCoffee} from './brewCielo.js'

dirRoot = undef
lFiles = []            # to process individual files

# --- Default values for flags
doWatch = false        # set with -w
envOnly = false        # set with -e
doDebug = false        # set with -d
quiet   = false        # set with -q
doForce = false        # set with -f
doExec = false         # execute *.js file for *.cielo files on cmd line
debugStarbucks = false # set with -s

readySeen = false      # set true when 'ready' event is seen

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	if ! quiet
		log "DIR_ROOT: #{dirRoot}"

	loadPrivEnvFrom(dirRoot)
	if envOnly
		doDebug = true
		checkDirs()
		logPrivEnv()
		process.exit()
	else
		checkDirs()

	if doDebug
		logPrivEnv()

	if nonEmpty(lFiles)
		# --- Process only these files
		nExec = 0           # --- number of files executed
		for path in lFiles
			brewFile path

			ext = fileExt(path)
			if ext == '.cielo'
				# --- *.coffee file was created, but we
				#     also want to create the *.js file
				brewFile withExt(path, '.coffee')

			if doExec && ((ext == '.cielo') || (ext == '.coffee'))
				# --- Execute the corresponding *.js file
				jsPath = withExt(path, '.js')

				# --- add separator line for 2nd and later executions
				if (nExec > 0)
					log sep_eq

				if doDebug
					log "...execute #{jsPath}"

				exec("node #{jsPath}", (err, stdout, stderr) ->
					if err
						log "exec() failed: #{err.message}"
					else
						log stdout
					)
	else
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
				if ! quiet
					log "#{event} #{shortenPath(path)}"
				ext = lMatches[0]
				if event == 'unlink'
					unlinkRelatedFiles(path, ext)
				else
					brewFile path
	return

# ---------------------------------------------------------------------------

brewFile = (path) ->

	if ! quiet
		log "   brew #{shortenPath(path)}"
	try
		switch fileExt(path)
			when '.cielo'
				brewCieloFile path
			when '.coffee'
				brewCoffeeFile path
			when '.starbucks'
				brewStarbucksFile path
			when '.taml'
				brewTamlFile path
			else
				croak "Unknown file type: #{path}"
	catch err
		log "   FAILED: #{err.message}"
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
		if ! quiet
			log "   unlink #{filename}"
		fs.unlinkSync fullpath
	catch err
		log "   FAILED: #{err.message}"
	return

# ---------------------------------------------------------------------------

needsUpdate = (srcPath, destPath) ->

	if doForce || readySeen
		return true
	if newerDestFileExists(srcPath, destPath)
		if doDebug || readySeen
			log "   dest exists"
		return false
	return true

# ---------------------------------------------------------------------------

brewCieloFile = (srcPath) ->
	# --- cielo => coffee

	destPath = withExt(srcPath, '.coffee')
	if needsUpdate(srcPath, destPath)
		coffeeCode = brewCielo(slurp(srcPath))
		output coffeeCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath) ->
	# --- coffee => js

	destPath = withExt(srcPath, '.js').replace('_', '')
	if needsUpdate(srcPath, destPath)
		jsCode = brewCoffee(slurp(srcPath))
		output jsCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (srcPath) ->

	destPath = withExt(srcPath, '.svelte').replace('_', '')
	if needsUpdate(srcPath, destPath)
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
	if needsUpdate(srcPath, destPath)
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
	if doDebug || readySeen
		log "   #{shortenPath(srcPath)} => #{shortenPath(destPath)}"
	return

# ---------------------------------------------------------------------------

parseCmdArgs = () ->

	# --- uses minimist
	hArgs = parseArgs(process.argv.slice(2), {
		boolean: words('h n e d q f x D'),
		unknown: (opt) ->
			return true
		})

	# --- Handle request for help
	if hArgs.h
		log "cielo [ <dir> ]"
		log "   -h help"
		log "   -w process files, then watch for changes"
		log "   -e just display custom environment variables"
		log "   -d turn on some debugging"
		log "   -q quiet output (only errors)"
		log "   -f initially, process all files, even up to date"
		log "   -x execute *.cielo files on cmd line"
		log "   -s dump input & output from starbucks conversions"
		log "   -D turn on debugging (a lot of output!)"
		log "<dir> defaults to current working directory"
		process.exit()

	doWatch = hArgs.w
	envOnly = hArgs.e
	doDebug = hArgs.d
	quiet   = hArgs.q
	doForce = hArgs.f
	doExec  = hArgs.x
	debugStarbucks = hArgs.s

	if hArgs.D
		setDebugging true

	if hArgs._?
		for path in hArgs._
			if path.indexOf('.') == 0
				path = getFullPath(path)  # converts \ to /
			else
				path = mkpath(path)    # convert \ to /
			if isDir(path)
				assert ! dirRoot, "multiple dirs not allowed"
				dirRoot = path
			else if isFile(path)
				lFiles.push path
			else
				croak "Invalid path '#{path}' on command line"

	if ! dirRoot
		if process.env.DIR_ROOT
			dirRoot = mkpath(process.env.DIR_ROOT)
		else
			dirRoot = process.env.DIR_ROOT = mkpath(process.cwd())

	# --- Convert any simple file names in lFiles to full path
	for path in lFiles
		if isSimpleFileName(path)
			path = mkpath(dirRoot, path)
	return

# ---------------------------------------------------------------------------

checkDir = (key) ->

	dir = hPrivEnv[key]
	if dir && ! fs.existsSync(dir)
		if doDebug
			warn "directory #{key} '#{dir}' does not exist - removing"
		delete hPrivEnv[key]
	return

# ---------------------------------------------------------------------------

checkDirs = () ->

	for key of hPrivEnv
		if key.match(/^DIR_/)
			checkDir(key)
	return

# ---------------------------------------------------------------------------

main()
