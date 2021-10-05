`#!/usr/bin/env node
`
import {strict as assert} from 'assert'
import parseArgs from 'minimist'
import {parse as parsePath} from 'path'
import chokidar from 'chokidar'

import {undef, croak, words} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, forEachFile, withExt, mkpath,
	} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {untabify} from '@jdeighan/coffee-utils/indent'
import {loadEnvFrom} from '@jdeighan/env'
import {starbucks} from '@jdeighan/starbucks'
import {brewCielo} from './brewCielo.js'

###
	cielo [-h | -n | -d | -D ]
###

doLog = false    # log files processed
doWatch = true   # turn off with -n

dirRoot = process.cwd()

# ---------------------------------------------------------------------------

main = () ->

	handleCmdArgs()
	loadEnvFrom dirRoot

	log "...processing #{dirRoot}"
	watcher = chokidar.watch(dirRoot, {
		persistent: doWatch,
		})
	watcher.on 'all', (event, path) ->
		if path.match(/node_modules/)
			return
		if lMatches = path.match(/\.(cielo|starbucks)$/)
			ext = ".#{lMatches[1]}"
			if doLog
				console.log event, path
			if ext == '.cielo'
				brewCieloFile(path)
			else if ext == 'starbucks'
				brewStarbucksFile(path)

	return

# ---------------------------------------------------------------------------

brewCieloFile = (path) ->

	code = brewCielo(slurp(path), 'js')
	output code, path, '.js'
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (path) ->

	hParsed = parsePath(path)
	hOptions = {
		content: slurp(path),
		filename: hParsed.base,
		}
	code = starbucks(hOptions).code
	output code, path, '.svelte'
	return

# ---------------------------------------------------------------------------

output = (code, inpath, outExt) ->

	outpath = withExt(inpath, outExt)
	barf outpath, code
	if doLog
		log "   #{inpath} => #{outExt}"
	return

# ---------------------------------------------------------------------------

handleCmdArgs = () ->

	hArgs = parseArgs(process.argv.slice(2), {
			boolean: words('h n d D'),
			unknown: (opt) ->
				return true
			})

	# --- Handle request for help
	if hArgs.h
		log "cielo"
		log "   -h help"
		log "   -n process files, don't watch for changes"
		log "   -d print every file processed"
		log "   -D turn on debugging (a lot of output!)"
		process.exit()

	if hArgs.d
		log "debugging on"
		doLog = true

	if hArgs.D
		log "extensive debugging on"
		setDebugging true

	if hArgs.n
		log "not watching for changes"
		doWatch = false

# ---------------------------------------------------------------------------

main()
