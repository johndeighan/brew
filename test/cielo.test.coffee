# cielo.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {hEnvLib} from '@jdeighan/coffee-utils/envlib'
import {loadEnvLibFrom} from '@jdeighan/env'
import {brewCielo} from '../bin/brewCielo.js'

dir = mydir(`import.meta.url`)
hEnvLib.DIR_MARKDOWN = mkpath(dir, 'markdown')
hEnvLib.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

###
	brewCielo() should handle the following:
		- should NOT remove blank lines and comments
		- #include <file> statements, when DIR_* env vars are set
		- patch {{FILE}} with the name of the input file
		- patch {{LINE}} with the line number
		- handle continuation lines
		- handle HEREDOC - a single '.' on a line is a blank line
		- add auto-imports
###

# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->
		return brewCielo(code, 'coffee')

	normalize: (line) ->  # disable normalizing, to check proper indentation
		return line

cieloTester = new CieloTester()

# ---------------------------------------------------------------------------
# --- Should NOT remove blank lines and comments

cieloTester.equal 45, """
		x = 42
		# --- a blank line

		console.log x
		""", """
		x = 42
		# --- a blank line

		console.log x
		"""

# ---------------------------------------------------------------------------
# --- maintain indentation - simple

cieloTester.equal 60, """
		if (x==42)
			console.log x
		""", """
		if (x==42)
			console.log x
		"""

# ---------------------------------------------------------------------------
# --- maintain indentation - complex

cieloTester.equal 71, """
		x = 42
		if (x==42)
			console.log x
			if (x > 100)
				console.log "x is big"
		""", """
		x = 42
		if (x==42)
			console.log x
			if (x > 100)
				console.log "x is big"
		"""

# ---------------------------------------------------------------------------
# --- handle #include of *.txt files

cieloTester.equal 88, """
		if (x==42)
			#include code.txt
		""", """
		if (x==42)
			y = 5
			if (y > 100)
				console.log "y is big"
		"""

# ---------------------------------------------------------------------------
# --- patch {{LINE}} and {{FILE}}

cieloTester.equal 101, """
		if (x==42)
			log "line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x==42)
			log "line 2 in unit test"
		"""

# ---------------------------------------------------------------------------
# --- handle continuation lines

cieloTester.equal 113, """
		if
					(x==42)
			log
					"line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x==42)
			log "line 4 in unit test"
		"""

# ---------------------------------------------------------------------------
# --- handle HEREDOC

cieloTester.equal 127, """
		if (x=='<<<')
			abc

			log "line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x=='abc')
			log "line 4 in unit test"
		"""

# --- a '---' starting a HEREDOC means interpret as TAML,
#             return as JSON.stringify()

cieloTester.equal 141, """
		if (x==<<<)
			---
			abc

			log "line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x=="abc")
			log "line 5 in unit test"
		"""

# --- NOTE: the following 2 tests are really the same thing

cieloTester.equal 155, """
		if (x=="<<<")
			abc
			def

			log "line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x=="abc\ndef")
			log "line 5 in unit test"
		"""

cieloTester.equal 167, """
		if (x=="<<<")
			abc
			def

			log "line {{LINE}} in {{FILE}}"
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		if (x=="abc
def")
			log "line 5 in unit test"
		"""

# ---------------------------------------------------------------------------

cieloTester.equal 182, """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		""", """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		"""
# ---------------------------------------------------------------------------
