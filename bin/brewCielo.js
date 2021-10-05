// brewCielo.coffee
var CieloMapper;

import {
  strict as assert
} from 'assert';

import CoffeeScript from 'coffeescript';

import {
  isEmpty,
  croak
} from '@jdeighan/coffee-utils';

import {
  indentLevel
} from '@jdeighan/coffee-utils/indent';

import {
  joinBlocks
} from '@jdeighan/coffee-utils/block';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  SmartInput
} from '@jdeighan/string-input';

import {
  getNeededSymbols,
  buildImportList
} from '@jdeighan/string-input/coffee';

// ---------------------------------------------------------------------------
CieloMapper = class CieloMapper extends SmartInput {
  // --- retain empty lines & comments
  handleEmptyLine(level) {
    // --- keep empty lines
    return '';
  }

  handleComment(line, level) {
    // --- keep comments
    return line;
  }

};

// ---------------------------------------------------------------------------
// --- Features:
//        1. KEEP blank lines and comments
//        2. #include <file>
//        3. replace {{FILE}} and {{LINE}}
//        4. handle continuation lines
//        5. handle HEREDOC
//        6. stop on __END__
//        7. add auto-imports
export var brewCielo = function(code, type) {
  var coffeeCode, err, jsCode, lImports, lNeeded, oInput;
  assert((type === 'coffee') || (type === 'js') || (type === 'both'), "brewCielo(): bad type");
  debug("enter brewCielo()");
  assert(indentLevel(code) === 0, "brewCielo(): code has indentation");
  // --- CieloMapper handles the above conversions
  oInput = new CieloMapper(code);
  coffeeCode = oInput.getAllText();
  // --- returns [<symbol>, ... ]
  lNeeded = getNeededSymbols(coffeeCode);
  if (!isEmpty(lNeeded)) {
    lImports = buildImportList(lNeeded);
    coffeeCode = joinBlocks(...lImports, coffeeCode);
  }
  if (type === 'coffee') {
    debug("return from brewCielo()", coffeeCode);
    return coffeeCode;
  }
  try {
    jsCode = CoffeeScript.compile(coffeeCode, {
      bare: true
    });
    debug("brewCielo(): js code", jsCode);
  } catch (error) {
    err = error;
    croak(err, "Original Code", coffeeCode);
  }
  debug("return from brewCielo()", jsCode);
  if (type === 'js') {
    return jsCode;
  } else if (type === 'both') {
    return [coffeeCode, jsCode];
  }
};
