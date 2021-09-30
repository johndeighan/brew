# brewCielo.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {isEmpty, croak} from '@jdeighan/coffee-utils'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {SmartInput} from '@jdeighan/string-input'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/string-input/coffee'

# ---------------------------------------------------------------------------

class CieloMapper extends SmartInput
	# --- retain empty lines & comments

	handleEmptyLine: (level) ->
		# --- keep empty lines
		return ''

	handleComment: (line, level) ->
		# --- keep comments
		return line

# ---------------------------------------------------------------------------
# --- Features:
#        1. KEEP blank lines and comments
#        2. #include <file>
#        3. replace {{FILE}} and {{LINE}}
#        4. handle continuation lines
#        5. handle HEREDOC
#        6. stop on __END__
#        7. add auto-imports

export brewCielo = (code, type) ->

	assert (type=='coffee') || (type=='js'), "brewCielo(): bad type"
	debug "enter brewCielo()"
	assert (indentLevel(code)==0), "brewCielo(): code has indentation"

	# --- CieloMapper handles the above conversions
	oInput = new CieloMapper(code)
	coffeeCode = oInput.getAllText()

	# --- returns [<symbol>, ... ]
	lNeeded = getNeededSymbols(coffeeCode)

	if not isEmpty(lNeeded)
		lImports = buildImportList(lNeeded)
		coffeeCode = joinBlocks(lImports..., coffeeCode)

	if type == 'coffee'
		debug "return from brewCielo()", coffeeCode
		return coffeeCode

	try
		jsCode = CoffeeScript.compile(coffeeCode, {bare: true})
		debug "brewCielo(): js code", jsCode
	catch err
		croak err, "Original Code", coffeeCode
	debug "return from brewCielo()", jsCode
	return jsCode
