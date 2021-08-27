`#!/usr/bin/env node
`
# brew.coffee

import {existsSync} from 'fs'
import {strict as assert} from 'assert'

import {say, undef} from '@jdeighan/coffee-utils'
import {slurp, mydir, getFullPath} from '@jdeighan/coffee-utils/fs'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {untabify} from '@jdeighan/coffee-utils/indent'
import {loadEnvFrom} from '@jdeighan/env'
import {starbucks} from '@jdeighan/starbucks'

orgPath = process.argv[2]
debug "brew(): orgPath = '#{orgPath}'"
filepath = getFullPath(orgPath)
assert existsSync(filepath),
	"File '#{filepath}' (org='#{orgPath}') does not exist"
debug "filepath = '#{filepath}'"

dir = mydir(`import.meta.url`)
assert existsSync(dir)
loadEnvFrom(dir, {rootName: 'dir_root'})
debug "dump dir is '#{process.env.dir_dump}'"

content = slurp(filepath)
debug content, "CONTENT:"

result = starbucks({content, filename: filepath})
say untabify(result.code)
