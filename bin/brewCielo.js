// brewCielo.coffee
var CieloMapper;

import CoffeeScript from 'coffeescript';

import {
  assert,
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
export var brewCielo = function(code) {
  var coffeeCode, lImports, lNeeded, oInput;
  // --- cielo => coffee
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
  debug("return from brewCielo()", coffeeCode);
  return coffeeCode;
};

// ---------------------------------------------------------------------------
export var brewCoffee = function(code) {
  var err, jsCode;
  // --- coffee => js
  debug("enter brewCoffee()");
  assert(indentLevel(code) === 0, "brewCoffee(): code has indentation");
  try {
    jsCode = CoffeeScript.compile(code, {
      bare: true,
      header: false
    });
  } catch (error) {
    err = error;
    croak(err, "Original Coffee Code", code);
  }
  debug("return from brewCoffee()", jsCode);
  return jsCode;
};
