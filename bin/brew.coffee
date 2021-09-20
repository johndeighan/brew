# brew.coffee

import {strict as assert} from 'assert'
import {existsSync, lstatSync} from 'fs'
import {parse} from 'path'

import {undef, pass} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, barf, getFullPath, forEachFile, withExt, mkpath,
	} from '@jdeighan/coffee-utils/fs'
import {
	setDebugging, debugging, debug,
	} from '@jdeighan/coffee-utils/debug'
import {untabify} from '@jdeighan/coffee-utils/indent'
import {loadEnvFrom} from '@jdeighan/env'
import {starbucks} from '@jdeighan/starbucks'

###
	brew <file>   -- brew one file (*.starbucks or *.cielo)
	brew <dir>    -- brew all files in directory tree
###

# ---------------------------------------------------------------------------

main = () ->

	orgPath = process.argv[2]
	debug "brew(): orgPath = '#{orgPath}'"
	assert orgPath, "Missing file/directory name on command line"
	path = getFullPath(orgPath)  # resolve relative paths

	# --- may be a file or a directory
	assert existsSync(path), "'#{path}' does not exist"

	ent = lstatSync(path)
	if ent.isFile()
		{dir, ext, base} = parse(path)

		# --- Load environment from directory containing source file
		loadEnvFrom(dir)
		if debugging
			dumpDirs()

		if (ext == '.starbucks')
			brewStarbucksFile(dir, base)
		else if (ext == '.cielo')
			brewCieloFile(dir, base)
		else
			croak "Can't brew #{base}"
	else if ent.isDirectory()

		# --- Load environment from given directory
		loadEnvFrom(path)
		if debugging
			dumpDirs()
		brewDirectory(path)
	return

# ---------------------------------------------------------------------------

brewDirectory = (dir) ->

	debug "brew files in dir '#{dir}'"

	cbStarbucks = (base, dir, level) ->
		brewStarbucksFile(dir, base)
		return

	cbCielo = (base, dir, level) ->
		brewCieloFile(dir, base)
		return

	forEachFile(dir, cbStarbucks, /\.starbucks$/)
	forEachFile(dir, cbCielo, /\.cielo$/)
	return

# ---------------------------------------------------------------------------

brewStarbucksFile = (dir, base) ->

	path = mkpath(dir, base)
	debug "brew file #{base} in directory #{dir}"

	content = slurp(path)
	debug "CONTENT:", content

	result = starbucks({content, filename: base})
	barf withExt(path, '.svelte'), untabify(result.code)
	debug "BREW: #{path} -> *.svelte"
	return

# ---------------------------------------------------------------------------

brewCieloFile = (dir, base) ->

	path = mkpath(dir, base)
	debug "brew file #{base} in directory #{dir}"

	content = slurp(path)
	debug "CONTENT:", content

#	result = starbucks({content, filename: base})
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
