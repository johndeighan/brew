// `#!/usr/bin/env node
// `
var brew, brewDirectory, doCieloToCoffee, doCieloToJS, doLog, doStarbucks, dumpDirs, lLoadedEnvPaths, loadEnvironment, main;

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
  starbucks
} from '@jdeighan/starbucks';

import {
  brewCielo
} from './brewCielo.js';

/*
	cielo [-c | -j | -s | -h | -d | -D ] (<dir> | <file>)+
*/
// --- default settings
doCieloToCoffee = false;

doCieloToJS = true;

doStarbucks = true;

doLog = false;

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
  var base, dir, ent, ext, hArgs, i, j, lPaths, len, len1, orgPath, path, ref;
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('c j s h d D'),
    unknown: function(opt) {
      return true;
    }
  });
  // --- Handle request for help
  if (hArgs.h) {
    console.log("cielo dir or file");
    console.log("   -c convert *.cielo to *.coffee files");
    console.log("   -j convert *.cielo to *.js files");
    console.log("   -s convert *.starbucks to *.svelte files");
    console.log("   -d print every file processed");
    console.log("   -D turn on debugging (a lot of output!)");
    console.log("   -h help");
    process.exit();
  }
  if (hArgs.d) {
    doLog = true;
    log("hArgs", hArgs);
  }
  if (hArgs.D) {
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
  //	if (hArgs._.length == 0)
  //		croak "Missing file/directory name on command line"

  // --- Resolve paths, checking that they all exist
  lPaths = [];
  ref = hArgs._;
  for (i = 0, len = ref.length; i < len; i++) {
    orgPath = ref[i];
    debug(`cielo(): orgPath = '${orgPath}'`);
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
        brew(dir, base, '.starbucks', '.svelte');
      } else if (ext === '.cielo') {
        if (doCieloToCoffee) {
          brew(dir, base, '.cielo', '.coffee');
        } else {
          brew(dir, base, '.cielo', '.js');
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
      brew(dir, base, '.cielo', '.coffee');
    };
    forEachFile(dir, cbCieloToCoffee, /\.cielo$/);
  }
  if (doCieloToJS) {
    cbCieloToJS = function(base, dir, level) {
      brew(dir, base, '.cielo', '.js');
    };
    forEachFile(dir, cbCieloToJS, /\.cielo$/);
  }
  if (doStarbucks) {
    cbStarbucks = function(base, dir, level) {
      brew(dir, base, '.starbucks', '.svelte');
    };
    forEachFile(dir, cbStarbucks, /\.starbucks$/);
  }
};

// ---------------------------------------------------------------------------
brew = function(dir, filename, srcExt, destExt) {
  var content, outpath, path, result;
  path = mkpath(dir, filename);
  content = slurp(path);
  if (srcExt === '.starbucks') {
    assert(destExt === '.svelte', `brew(): Bad dest ext ${destExt}`);
    result = starbucks({content, filename}).code;
  } else if (srcExt === '.cielo') {
    if (destExt === '.coffee') {
      result = brewCielo(content, 'coffee');
    } else if (destExt === '.js') {
      result = brewCielo(content, 'js');
    } else {
      croak(`brew(): Unknown dest extension: ${destExt}`);
    }
  } else {
    croak(`brew(): Unknown source extension: ${srcExt}`);
  }
  outpath = withExt(path, destExt);
  barf(outpath, untabify(result));
  debug(`BREW: ${path} -> ${outpath}`);
  if (doLog) {
    log(dir);
    log(`   ${base} => ${withExt(base, outExt)}`);
  }
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
