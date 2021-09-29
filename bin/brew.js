// brew.coffee
var brewCieloFileToCoffee, brewCieloFileToJS, brewDirectory, brewStarbucksFile, doCieloToCoffee, doCieloToJS, doStarbucks, dumpDirs, lLoadedEnvPaths, loadEnvironment, main;

import {
  strict as assert
} from 'assert';

import {
  existsSync,
  lstatSync
} from 'fs';

import {
  parse
} from 'path';

import parseArgs from 'minimist';

import {
  undef,
  pass,
  croak,
  words
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  barf,
  getFullPath,
  forEachFile,
  withExt,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  setDebugging,
  debugging,
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  untabify
} from '@jdeighan/coffee-utils/indent';

import {
  loadEnvFrom
} from '@jdeighan/env';

import {
  brewCielo,
  brewCoffee
} from '@jdeighan/string-input/coffee';

import {
  starbucks
} from '@jdeighan/starbucks';

/*
	cielo [-c | -j | -s | -h | -d ] (<dir> | <file>)+
*/
// --- default settings
doCieloToCoffee = false;

doCieloToJS = true;

doStarbucks = true;

// ---------------------------------------------------------------------------
lLoadedEnvPaths = [];

loadEnvironment = function(dir) {
  if (!lLoadedEnvPaths.includes(dir)) {
    loadEnvFrom(dir);
    lLoadedEnvPaths.push(dir);
    if (debugging) {
      dumpDirs();
    }
  }
};

// ---------------------------------------------------------------------------
main = function() {
  var base, dir, ent, ext, hArgs, i, j, lArgs, lPaths, len, len1, orgPath, path, ref;
  lArgs = process.argv.slice(2);
  //	console.log "ARGS:"
  //	console.dir lArgs
  hArgs = parseArgs(lArgs, {
    boolean: words('c j s h d'),
    unknown: function(opt) {
      return true;
    }
  });
  //	console.log "hArgs:"
  //	console.dir hArgs

  // --- Handle request for help
  if (hArgs.h) {
    console.log("cielo dir or file");
    console.log("   -c convert *.cielo to *.coffee files");
    console.log("   -j convert *.cielo to *.js files");
    console.log("   -s convert *.starbucks to *.svelte files");
    console.log("   -h help");
    process.exit();
  }
  if (hArgs.d) {
    setDebugging(true);
  }
  // --- If neither -c, -j or -s are set, we'll process both types of files
  //     But that only applies to directories - starbucks and cielo files
  //     appearing on the command line are always processed
  if (hArgs.c || hArgs.j || hArgs.s) {
    doCieloToCoffee = hArgs.c;
    doCieloToJS = hArgs.j;
    doStarbucks = hArgs.s;
  }
  if (hArgs._.length === 0) {
    croak("Missing file/directory name on command line");
  }
  // --- Resolve paths, checking that they all exist
  lPaths = [];
  ref = hArgs._;
  for (i = 0, len = ref.length; i < len; i++) {
    orgPath = ref[i];
    debug(`brew(): orgPath = '${orgPath}'`);
    path = getFullPath(orgPath); // resolve relative paths
    debug(`resolved to '${path}'`);
    // --- may be a file or a directory
    assert(existsSync(path), `'${path}' does not exist`);
    lPaths.push(path);
  }
  for (j = 0, len1 = lPaths.length; j < len1; j++) {
    path = lPaths[j];
    ent = lstatSync(path);
    if (ent.isFile()) {
      ({dir, ext, base} = parse(path));
      // --- Load environment from directory containing source file
      loadEnvironment(dir);
      if (ext === '.starbucks') {
        brewStarbucksFile(dir, base);
      } else if (ext === '.cielo') {
        if (doCieloToCoffee) {
          brewCieloFileToCoffee(dir, base);
        } else {
          brewCieloFileToJS(dir, base);
        }
      } else {
        croak(`Can't brew ${base}`);
      }
    } else if (ent.isDirectory()) {
      // --- Load environment from given directory
      loadEnvironment(path);
      brewDirectory(path);
    }
  }
};

// ---------------------------------------------------------------------------
brewDirectory = function(dir) {
  var cbCieloToCoffee, cbCieloToJS, cbStarbucks;
  debug(`brew files in dir '${dir}'`);
  if (doCieloToCoffee) {
    cbCieloToCoffee = function(base, dir, level) {
      brewCieloFileToCoffee(dir, base);
    };
    forEachFile(dir, cbCieloToCoffee, /\.cielo$/);
  }
  if (doCieloToJS) {
    cbCieloToJS = function(base, dir, level) {
      brewCieloFileToJS(dir, base);
    };
    forEachFile(dir, cbCieloToJS, /\.cielo$/);
  }
  if (doStarbucks) {
    cbStarbucks = function(base, dir, level) {
      brewStarbucksFile(dir, base);
    };
    forEachFile(dir, cbStarbucks, /\.starbucks$/);
  }
};

// ---------------------------------------------------------------------------
brewStarbucksFile = function(dir, base) {
  var content, path, result;
  path = mkpath(dir, base);
  content = slurp(path);
  result = starbucks({
    content,
    filename: base
  });
  barf(withExt(path, '.svelte'), untabify(result.code));
  debug(`BREW: ${path} -> *.svelte`);
};

// ---------------------------------------------------------------------------
brewCieloFileToCoffee = function(dir, base) {
  var code, newcode, newpath, path;
  path = mkpath(dir, base);
  code = slurp(path);
  newcode = brewCielo(code);
  newpath = withExt(path, '.coffee');
  barf(newpath, newcode);
  debug(`BREW: ${path} -> ${newpath}`);
};

// ---------------------------------------------------------------------------
brewCieloFileToJS = function(dir, base) {
  var content;
  content = slurp(mkpath(dir, base));
  barf(withExt(path, '.coffee'), result);
  debug(`BREW: ${path} -> *.coffee`);
};

// ---------------------------------------------------------------------------
dumpDirs = function() {
  var key, ref, value;
  ref = process.env;
  // --- Print out names of defined directories
  for (key in ref) {
    value = ref[key];
    if ((key.indexOf('DIR_') === 0) || (key.indexOf('dir_') === 0)) {
      log(`${key} = ${value}`);
    }
  }
};

// ---------------------------------------------------------------------------
main();
