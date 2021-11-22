// brewCielo.coffee
var CieloMapper, dumpStats, nProcessed;

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
  log
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  barf
} from '@jdeighan/coffee-utils/fs';

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
  return {
    code: coffeeCode
  };
};

// ---------------------------------------------------------------------------
export var brewCieloFile = function(srcPath) {
  var code;
  code = slurp(srcPath);
  return brewCielo(code);
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
  return {
    code: jsCode
  };
};

// ---------------------------------------------------------------------------
export var brewCoffeeFile = function(srcPath) {
  var code;
  code = slurp(srcPath);
  return brewCoffee(code);
};

// ---------------------------------------------------------------------------
nProcessed = 0;

// ---------------------------------------------------------------------------
export var output = function(code, srcPath, destPath, quiet = false) {
  var err;
  try {
    barf(destPath, code);
    nProcessed += 1;
  } catch (error) {
    err = error;
    log(`ERROR: ${err.message}`);
  }
  if (!quiet) {
    log(`   => ${shortenPath(destPath)}`);
  }
};

// ---------------------------------------------------------------------------
dumpStats = function(quiet) {
  if (!quiet) {
    log(`${nProcessed} files processed`);
  }
};

// ---------------------------------------------------------------------------
