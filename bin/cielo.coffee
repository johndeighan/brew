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

###
	cielo [-h | -n | -e | -d | -f | -D | -x ] [ <files or directory> ]
###

dirRoot = undef
lFiles = []            # to process individual files

doForce = false        # turn on with -f
doWatch = true         # turn off with -n
doExec = false         # execute *.js file for *.cielo files on cmd line
envOnly = false        # set with -e
debugStarbucks = false # set with -D
readySeen = false      # set true when 'ready' event is seen

# ---------------------------------------------------------------------------

main = () ->

	parseCmdArgs()
	log "DIR_ROOT: #{dirRoot}"

	loadPrivEnvFrom(dirRoot)
	checkDirs()
	logPrivEnv()
	if envOnly
		process.exit()

	if nonEmpty(lFiles)
		# --- Process only these files
		for path in lFiles
			ext = fileExt(path)
			brewFile path
			if ext == '.cielo'
				# --- *.coffee file was created, but we
				#     also want to create the *.js file
				brewFile withExt(path, '.coffee')

			if doExec && ((ext == '.cielo') || (ext == '.coffee'))
				# --- Execute the corresponding *.js file
				jsPath = withExt(path, '.js')
				exec("node #{jsPath}", (err, stdout, stderr) ->
					if err
						log "exec() failed: #{err.message}"
					else
						log stdout
					)
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
				brewFile path
		return

	return

# ---------------------------------------------------------------------------

brewFile = (path) ->

	log "brew #{shortenPath(path)}"
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

doProcess = (srcPath, destPath) ->

	if doForce || readySeen
		return true
	if newerDestFileExists(srcPath, destPath)
		log "   dest exists"
		return false
	return true

# ---------------------------------------------------------------------------

brewCieloFile = (srcPath) ->
	# --- cielo => coffee

	destPath = withExt(srcPath, '.coffee')
	if doProcess(srcPath, destPath)
		coffeeCode = brewCielo(slurp(srcPath))
		output coffeeCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath) ->
	# --- coffee => js

	destPath = withExt(srcPath, '.js').replace('_', '')
	if doProcess(srcPath, destPath)
		jsCode = brewCoffee(slurp(srcPath))
		output jsCode, srcPath, destPath
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (srcPath) ->

	destPath = withExt(srcPath, '.svelte').replace('_', '')
	if doProcess(srcPath, destPath)
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
	if doProcess(srcPath, destPath)
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
		boolean: words('h n e d f x D'),
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
		log "   -f initially, process all files, even up to date"
		log "   -x execute *.cielo files on cmd line"
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

	if hArgs.f
		doForce = true

	if hArgs.x
		doExec = true

	if hArgs.D
		log "debugging starbucks conversions"
		debugStarbucks = true

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

checkDir = (name) ->

	dir = hPrivEnv[name]
	if dir && ! fs.existsSync(dir)
		warn "directory #{dir} does not exist - removing"
		delete hPrivEnv[name]
	return

# ---------------------------------------------------------------------------

checkDirs = () ->

	for key of hPrivEnv
		if key.match(/^DIR_/)
			checkDir(key)
	return

# ---------------------------------------------------------------------------

main()
