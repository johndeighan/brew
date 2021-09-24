# brew.coffee

import {strict as assert} from 'assert'
import {existsSync, lstatSync} from 'fs'
import {parse} from 'path'
import parseArgs from 'minimist';

import {undef, pass, croak, words} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, getFullPath, forEachFile, withExt, mkpath,
	} from '@jdeighan/coffee-utils/fs'
import {
	setDebugging, debugging, debug,
	} from '@jdeighan/coffee-utils/debug'
import {untabify} from '@jdeighan/coffee-utils/indent'
import {loadEnvFrom} from '@jdeighan/env'
import {brewCielo, brewCoffee} from '@jdeighan/string-input/coffee'
import {starbucks} from '@jdeighan/starbucks'

###
	cielo [-c | -j | -s | -h | -d ] (<dir> | <file>)+
###

# --- default settings
doCieloToCoffee = false
doCieloToJS = true
doStarbucks = true

# ---------------------------------------------------------------------------

lLoadedEnvPaths = []

loadEnvironment = (dir) ->

	if not lLoadedEnvPaths.includes(dir)
		loadEnvFrom(dir)
		lLoadedEnvPaths.push dir
		if debugging
			dumpDirs()
	return

# ---------------------------------------------------------------------------

main = () ->

	lArgs = process.argv.slice(2)
#	console.log "ARGS:"
#	console.dir lArgs

	hArgs = parseArgs(lArgs, {
			boolean: words('c j s h d'),
			unknown: (opt) ->
				return true
			})

#	console.log "hArgs:"
#	console.dir hArgs

	# --- Handle request for help
	if hArgs.h
		console.log "cielo dir or file"
		console.log "   -c convert *.cielo to *.coffee files"
		console.log "   -j convert *.cielo to *.js files"
		console.log "   -s convert *.starbucks to *.svelte files"
		console.log "   -h help"
		process.exit()

	if hArgs.d
		setDebugging true

	# --- If neither -c, -j or -s are set, we'll process both types of files
	#     But that only applies to directories - starbucks and cielo files
	#     appearing on the command line are always processed

	if hArgs.c || hArgs.j || hArgs.s
		doCieloToCoffee = hArgs.c
		doCieloToJS = hArgs.j
		doStarbucks = hArgs.s

	if (hArgs._.length == 0)
		croak "Missing file/directory name on command line"

	# --- Resolve paths, checking that they all exist
	lPaths = []
	for orgPath in hArgs._
		debug "brew(): orgPath = '#{orgPath}'"
		path = getFullPath(orgPath)  # resolve relative paths
		debug "resolved to '#{path}'"

		# --- may be a file or a directory
		assert existsSync(path), "'#{path}' does not exist"
		lPaths.push path

	for path in lPaths
		ent = lstatSync(path)
		if ent.isFile()
			{dir, ext, base} = parse(path)

			# --- Load environment from directory containing source file
			loadEnvironment dir

			if (ext == '.starbucks')
				brewStarbucksFile(dir, base)
			else if (ext == '.cielo')
				if doCieloToCoffee
					brewCieloFileToCoffee(dir, base)
				else
					brewCieloFileToJS(dir, base)
			else
				croak "Can't brew #{base}"
		else if ent.isDirectory()

			# --- Load environment from given directory
			loadEnvironment path
			brewDirectory(path)
	return

# ---------------------------------------------------------------------------

brewDirectory = (dir) ->

	debug "brew files in dir '#{dir}'"

	if doCieloToCoffee
		cbCieloToCoffee = (base, dir, level) ->
			brewCieloFileToCoffee(dir, base)
			return

		forEachFile(dir, cbCieloToCoffee, /\.cielo$/)

	if doCieloToJS
		cbCieloToJS = (base, dir, level) ->
			brewCieloFileToJS(dir, base)
			return

		forEachFile(dir, cbCieloToJS, /\.cielo$/)

	if doStarbucks
		cbStarbucks = (base, dir, level) ->
			brewStarbucksFile(dir, base)
			return

		forEachFile(dir, cbStarbucks, /\.starbucks$/)
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (dir, base) ->

	path = mkpath(dir, base)
	content = slurp(path)
	result = starbucks({content, filename: base})
	barf withExt(path, '.svelte'), untabify(result.code)
	debug "BREW: #{path} -> *.svelte"
	return

# ---------------------------------------------------------------------------

brewCieloFileToCoffee = (dir, base) ->

	code = slurp(mkpath(dir, base))
	newcode = brewCielo(code)
	newpath = withExt(path, '.coffee')
	barf newpath, newcode
	debug "BREW: #{path} -> #{newpath}"
	return

# ---------------------------------------------------------------------------

brewCieloFileToJS = (dir, base) ->

	content = slurp(mkpath(dir, base))
	barf withExt(path, '.coffee'), result
	debug "BREW: #{path} -> *.coffee"
	return

# ---------------------------------------------------------------------------

dumpDirs = () ->

	# --- Print out names of defined directories
	for key,value of process.env
		if (key.indexOf('DIR_') == 0) || (key.indexOf('dir_') == 0)
			log "#{key} = #{value}"
	return

# ---------------------------------------------------------------------------

main()
