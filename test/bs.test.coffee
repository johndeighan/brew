import {pathTo} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/unit-tester'
import {mydir} from '@jdeighan/coffee-utils/fs'

dir = mydir(import.meta.url)

simple = new UnitTester()
simple.equal 4, pathTo('test.txt', dir), "#{dir}/subdirectory/test.txt"
