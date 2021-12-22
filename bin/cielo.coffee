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
	slurp, barf, withExt, mkpath, forEachFile, newerDestFileExists,
	shortenPath, isFile, isDir, isSimpleFileName, getFullPath,
	fileExt
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {loadEnv} from '@jdeighan/env'
import {getNeededSymbols} from '@jdeighan/string-input/coffee'
import {isTAML, taml} from '@jdeighan/string-input/taml'
import {starbucks} from '@jdeighan/starbucks'
import {brewCieloFile} from '@jdeighan/string-input/cielo'
import {brewCoffee} from '@jdeighan/string-input/coffee'

dirRoot = undef        # set in parseCmdArgs()
lFiles = []            # to process individual files

# --- Default values for flags
doWatch = false        # set with -w
envOnly = false        # set with -e
doDebug = false        # set with -d
quiet   = false        # set with -q
doForce = false        # set with -f
doExec = false         # execute *.js file for *.cielo files on cmd line
debugStarbucks = false # set with -s
saveAST = false        # set with -A

readySeen = false      # set true when 'ready' event is seen
nProcessed = 0
nExecuted = 0

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	process.env.DIR_ROOT = dirRoot
	loadEnv()
	if envOnly
		doDebug = true
		checkDirs()
		process.exit()

	checkDirs()
	if nonEmpty(lFiles)
		# --- Process only these files
		for path in lFiles
			if ! quiet
				log "BREW #{shortenPath(path)}"
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
				if (nExecuted > 0)
					log sep_eq

				if doDebug
					log "...execute #{jsPath}"

				exec("node #{jsPath}", (err, stdout, stderr) ->
					if err
						log "exec() failed: #{err.message}"
					else
						log stdout
					)
				nExecuted += 1

		dumpStats()
		return   # --- DONE

	watcher = chokidar.watch(dirRoot, {
		persistent: doWatch,
		})

	watcher.on 'ready', () ->

		if ! quiet
			if doWatch
				log "...watching for further file changes"
			else
				log "...not watching for further file changes"
				dumpStats()
		readySeen = true

	watcher.on 'all', (event, path) ->

		# --- never process files in a node_modules directory
		#     or any directory whose name begins with '.'
		if path.match(/node_modules/) || path.match(/[\/\\]\./)
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

dumpStats = () ->

	if quiet
		return
	log "#{nProcessed} files processed"
	if doExec
		log "#{nExecuted} files executed"
	return

# ---------------------------------------------------------------------------

brewFile = (path) ->

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

needsUpdate = (srcPath, destPath) ->

	if doForce || readySeen
		return true
	if newerDestFileExists(srcPath, destPath)
		if ! quiet
			log "   UP TO DATE"
		return false
	return true

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath) ->
	# --- coffee => js

	destPath = withExt(srcPath, '.js', {removeLeadingUnderScore:true})
	if needsUpdate(srcPath, destPath)
		coffeeCode = slurp(srcPath)
		if saveAST
			dumpfile = withExt(srcPath, '.ast')
			lNeeded = getNeededSymbols(coffeeCode, {dumpfile})
			if (lNeeded == undef) || (lNeeded.length == 0)
				log "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				log "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					log "   - #{sym}"
		hCoffee = brewCoffee(coffeeCode)
		output hCoffee.code, srcPath, destPath, quiet
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (srcPath) ->

	destPath = withExt(srcPath, '.svelte', {removeLeadingUnderScore:true})
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
		output code, srcPath, destPath, quiet
	return

# ---------------------------------------------------------------------------

brewTamlFile = (srcPath) ->

	destPath = withExt(srcPath, '.js', {removeLeadingUnderScore:true})
	if needsUpdate(srcPath, destPath)
		hInfo = pathlib.parse(destPath)
		stub = hInfo.name

		tamlCode = slurp(srcPath)
		output("""
			import {TAMLDataStore} from '@jdeighan/starbucks/stores';

			export let #{stub} = new TAMLDataStore(`#{tamlCode}`);
			""", srcPath, destPath, quiet)
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
				removeFile(path, '.js', {removeLeadingUnderScore:true})
		when '.starbucks'
			if path.indexOf('_') == -1
				removeFile(path, '.svelte')
			else
				removeFile(path, '.svelte', {removeLeadingUnderScore:true})
		else
			croak "Invalid file extension: '#{ext}'"
	return

# ---------------------------------------------------------------------------

removeFile = (path, ext, hOptions={}) ->
	# --- file 'path' was removed
	#     remove same file, but with ext 'ext'
	#     valid options: same as withExt()

	fullpath = withExt(path, ext, hOptions)
	try
		if ! quiet
			log "   unlink #{filename}"
		fs.unlinkSync fullpath
	catch err
		log "   FAILED: #{err.message}"
	return

# ---------------------------------------------------------------------------

dumpOptions = () ->

	log "OPTIONS:"
	log "   doWatch = #{doWatch}"
	log "   envOnly = #{envOnly}"
	log "   doDebug = #{doDebug}"
	log "   quiet = #{quiet}"
	log "   doForce = #{doForce}"
	log "   doExec = #{doExec}"
	log "   debugStarbucks = #{debugStarbucks}"
	log "   saveAST = #{saveAST}"
	return

# ---------------------------------------------------------------------------

parseCmdArgs = () ->

	# --- uses minimist
	hArgs = parseArgs(process.argv.slice(2), {
		boolean: words('h w e d q f x s D A'),
		unknown: (opt) ->
			return true
		})

	# --- Handle request for help
	if hArgs.h
		log "cielo { <dir> | <file> }"
		log "   -h help"
		log "   -w process files, then watch for changes"
		log "   -e just display custom environment variables"
		log "   -d turn on some debugging"
		log "   -q quiet output (only errors)"
		log "   -f initially, process all files, even up to date"
		log "   -x execute *.cielo files on cmd line"
		log "   -s dump input & output from starbucks conversions"
		log "   -D turn on debugging (a lot of output!)"
		log "   -A save CoffeeScript abstract syntax trees"
		log "<dir> defaults to current working directory"
		process.exit()

	doWatch = true if hArgs.w
	envOnly = true if hArgs.e
	doDebug = true if hArgs.d
	quiet   = true if hArgs.q
	doForce = true if hArgs.f
	doExec  = true if hArgs.x
	saveAST = true if hArgs.A
	debugStarbucks = true if hArgs.s

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

	for key of process.env
		if key.match(/^DIR_/)
			checkDir(key)
	return

# ---------------------------------------------------------------------------

export output = (code, srcPath, destPath, logit=false) ->

	try
		barf destPath, code
		nProcessed += 1
	catch err
		log "ERROR: #{err.message}"
	if ! quiet
		log "   => #{shortenPath(destPath)}"
	return

# ---------------------------------------------------------------------------

main()
