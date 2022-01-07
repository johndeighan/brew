#!/usr/bin/env node
;
var brewFile, checkDir, checkDirs, debugStarbucks, dirRoot, doDebug, doExec, doForce, doWatch, dumpOptions, dumpStats, envOnly, lFiles, main, nExecuted, nProcessed, needsUpdate, parseCmdArgs, procCieloFiles, procCoffeeFiles, procStarbucksFiles, procTamlFiles, quiet, readySeen, saveAST, unlinkRelatedFiles;

import parseArgs from 'minimist';

import pathlib from 'path';

import fs from 'fs';

import chokidar from 'chokidar';

import {
  exec
} from 'child_process';

import {
  assert,
  undef,
  warn,
  croak,
  words,
  sep_eq,
  nonEmpty,
  isString,
  isArray
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  barf,
  withExt,
  mkpath,
  forEachFile,
  newerDestFileExists,
  shortenPath,
  isFile,
  isDir,
  isSimpleFileName,
  getFullPath,
  fileExt,
  removeFileWithExt
} from '@jdeighan/coffee-utils/fs';

import {
  setDebugging,
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  loadEnvFrom
} from '@jdeighan/env';

import {
  getNeededSymbols
} from '@jdeighan/string-input/coffee';

import {
  isTAML,
  taml
} from '@jdeighan/string-input/taml';

import {
  starbucks,
  brewStarbucksFile
} from '@jdeighan/starbucks';

import {
  brewTamlFile
} from '@jdeighan/starbucks/stores';

import {
  brewCieloFile
} from '@jdeighan/string-input/cielo';

import {
  brewCoffeeFile
} from '@jdeighan/string-input/coffee';

dirRoot = undef; // set in parseCmdArgs()

lFiles = []; // to process individual files


// --- Default values for flags
doWatch = false; // set with -w

envOnly = false; // set with -e

doDebug = false; // set with -d

quiet = false; // set with -q

doForce = false; // set with -f

doExec = false; // execute *.js file for *.cielo files on cmd line

debugStarbucks = false; // set with -s

saveAST = false; // set with -A

procCieloFiles = false; // set with -c

procCoffeeFiles = false; // set with -k

procStarbucksFiles = false; // set with -s

procTamlFiles = false; // set with -t

readySeen = false; // set true when 'ready' event is seen

nProcessed = 0;

nExecuted = 0;

// ---------------------------------------------------------------------------
main = function() {
  var ext, i, jsPath, lEnvFiles, len, path, watcher;
  parseCmdArgs();
  if (doDebug) {
    log(`...loading env from ${dirRoot}`);
  }
  lEnvFiles = loadEnvFrom(dirRoot);
  if (envOnly) {
    doDebug = true;
    checkDirs();
    process.exit();
  }
  checkDirs();
  if (nonEmpty(lFiles)) {
// --- Process only these files
    for (i = 0, len = lFiles.length; i < len; i++) {
      path = lFiles[i];
      if (!quiet) {
        log(`BREW ${shortenPath(path)}`);
      }
      brewFile(path);
      ext = fileExt(path);
      if (ext === '.cielo') {
        // --- *.coffee file was created, but we
        //     also want to create the *.js file
        brewFile(withExt(path, '.coffee'));
      }
      if (doExec && ((ext === '.cielo') || (ext === '.coffee'))) {
        // --- Execute the corresponding *.js file
        jsPath = withExt(path, '.js');
        // --- add separator line for 2nd and later executions
        if (nExecuted > 0) {
          log(sep_eq);
        }
        if (doDebug) {
          log(`...execute ${jsPath}`);
        }
        exec(`node ${jsPath}`, function(err, stdout, stderr) {
          if (err) {
            return log(`exec() failed: ${err.message}`);
          } else {
            return log(stdout);
          }
        });
        nExecuted += 1;
      }
    }
    dumpStats(); // --- DONE
    return;
  }
  watcher = chokidar.watch(dirRoot, {
    persistent: doWatch
  });
  watcher.on('ready', function() {
    if (!quiet) {
      if (doWatch) {
        log("...watching for further file changes");
      } else {
        log("...not watching for further file changes");
        dumpStats();
      }
    }
    return readySeen = true;
  });
  watcher.on('all', function(event, path) {
    var lMatches;
    // --- never process files in a node_modules directory
    //     or any directory whose name begins with '.'
    assert(isString(path), "in watcher: path is not a string");
    if (path.match(/node_modules/) || path.match(/[\/\\]\./)) {
      return;
    }
    if (lMatches = path.match(/\.(?:cielo|coffee|starbucks|taml)$/)) {
      if (!quiet) {
        log(`${event} ${shortenPath(path)}`);
      }
      ext = lMatches[0];
      if (event === 'unlink') {
        return unlinkRelatedFiles(path, ext);
      } else {
        return brewFile(path);
      }
    }
  });
};

// ---------------------------------------------------------------------------
brewFile = function(path) {
  var force;
  switch (fileExt(path)) {
    case '.cielo':
      if (!procCieloFiles) {
        return;
      }
      brewCieloFile(path);
      break;
    case '.coffee':
      if (!procCoffeeFiles) {
        return;
      }
      force = doForce || readySeen;
      brewCoffeeFile(path, undef, {saveAST, force});
      break;
    case '.starbucks':
      if (!procStarbucksFiles) {
        return;
      }
      brewStarbucksFile(path);
      break;
    case '.taml':
      if (!procTamlFiles) {
        return;
      }
      brewTamlFile(path, undef, {force});
      break;
    default:
      croak(`Unknown file type: ${path}`);
  }
  nProcessed += 1;
};

// ---------------------------------------------------------------------------
needsUpdate = function(srcPath, destPath) {
  if (doForce || readySeen) {
    return true;
  }
  if (newerDestFileExists(srcPath, destPath)) {
    if (!quiet) {
      log("   UP TO DATE");
    }
    return false;
  }
  return true;
};

// ---------------------------------------------------------------------------
unlinkRelatedFiles = function(path, ext) {
  // --- file 'path' was removed
  switch (ext) {
    case '.cielo':
      removeFileWithExt(path, '.coffee');
      break;
    case '.coffee':
    case '.taml':
      if (path.indexOf('_') === -1) {
        removeFileWithExt(path, '.js');
      } else {
        removeFileWithExt(path, '.js', {
          removeLeadingUnderScore: true
        });
      }
      break;
    case '.starbucks':
      if (path.indexOf('_') === -1) {
        removeFileWithExt(path, '.svelte');
      } else {
        removeFileWithExt(path, '.svelte', {
          removeLeadingUnderScore: true
        });
      }
      break;
    default:
      croak(`Invalid file extension: '${ext}'`);
  }
};

// ---------------------------------------------------------------------------
dumpStats = function() {
  if (quiet) {
    return;
  }
  log(`${nProcessed} files processed`);
  if (doExec) {
    log(`${nExecuted} files executed`);
  }
};

// ---------------------------------------------------------------------------
dumpOptions = function() {
  log("OPTIONS:");
  log(`   procCieloFiles = ${procCieloFiles}`);
  log(`   procCoffeeFiles = ${procCoffeeFiles}`);
  log(`   procStarbucksFiles = ${procStarbucksFiles}`);
  log(`   procTamlFiles = ${procTamlFiles}`);
  log(`   doWatch = ${doWatch}`);
  log(`   envOnly = ${envOnly}`);
  log(`   doDebug = ${doDebug}`);
  log(`   quiet = ${quiet}`);
  log(`   doForce = ${doForce}`);
  log(`   doExec = ${doExec}`);
  log(`   debugStarbucks = ${debugStarbucks}`);
  log(`   saveAST = ${saveAST}`);
};

// ---------------------------------------------------------------------------
parseCmdArgs = function() {
  var hArgs, i, j, len, len1, newpath, path, ref;
  // --- uses minimist
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('h c k s t w e d q f x S D A'),
    unknown: function(opt) {
      return true;
    }
  });
  // --- Handle request for help
  if (hArgs.h) {
    log("cielo { <dir> | <file> }");
    log("   -h help");
    log("   -c process *.cielo files");
    log("   -k process *.coffee files");
    log("   -s process *.starbucks files");
    log("   -t process *.taml files");
    log("   -w process files, then watch for changes");
    log("   -e just display custom environment variables");
    log("   -d turn on some debugging");
    log("   -q quiet output (only errors)");
    log("   -f initially, process all files, even if up to date");
    log("   -x execute *.cielo files on cmd line");
    log("   -S dump input & output from starbucks conversions");
    log("   -D turn on debugging (a lot of output!)");
    log("   -A save CoffeeScript abstract syntax trees");
    log("<dir> defaults to current working directory");
    log("if none of -c, -k, -s or -t set, acts as if -ckst set");
    process.exit();
  }
  if (hArgs.d) {
    doDebug = true;
  }
  if (doDebug) {
    log("in parseCmdArgs()");
  }
  if (hArgs.c) {
    procCieloFiles = true;
  }
  if (hArgs.k) {
    procCoffeeFiles = true;
  }
  if (hArgs.s) {
    procStarbucksFiles = true;
  }
  if (hArgs.t) {
    procTamlFiles = true;
  }
  if (!procCieloFiles && !procCoffeeFiles && !procStarbucksFiles && !procTamlFiles) {
    procCieloFiles = true;
    procCoffeeFiles = true;
    procStarbucksFiles = true;
    procTamlFiles = true;
  }
  if (hArgs.w) {
    doWatch = true;
  }
  if (hArgs.e) {
    envOnly = true;
  }
  if (hArgs.q) {
    quiet = true;
  }
  if (hArgs.f) {
    doForce = true;
  }
  if (hArgs.x) {
    doExec = true;
  }
  if (hArgs.A) {
    saveAST = true;
  }
  if (hArgs.S) {
    debugStarbucks = true;
  }
  if (doDebug) {
    dumpOptions();
  }
  if (hArgs.D) {
    setDebugging(true);
  }
  if (hArgs._ != null) {
    ref = hArgs._;
    // --- Must be either a single directory
    //     or a list of file names (simple, relative or absolute)
    for (i = 0, len = ref.length; i < len; i++) {
      path = ref[i];
      if (path.indexOf('.') === 0) {
        // --- relative path - convert to absolute
        //     may be file or directory
        newpath = getFullPath(path); // converts \ to /
      } else if (isSimpleFileName(path)) {
        newpath = mkpath(process.cwd(), path);
      } else {
        newpath = mkpath(path); // convert \ to /
      }
      if (isDir(newpath)) {
        if (doDebug) {
          log(`found dir '${newpath}' (from '${path}')`);
        }
        assert(!dirRoot, "multiple dirs not allowed");
        dirRoot = newpath;
        if (!quiet) {
          log(`DIR_ROOT: ${dirRoot} (from cmd line)`);
        }
      } else if (isFile(newpath)) {
        if (doDebug) {
          log(`found file '${newpath}' (from '${path}')`);
        }
        lFiles.push(newpath);
      } else {
        croak(`Invalid path '${newpath}' on command line`);
      }
    }
  }
  if (!dirRoot) {
    dirRoot = mkpath(process.cwd());
    if (!quiet) {
      log(`DIR_ROOT: ${dirRoot} (from cwd())`);
    }
  }
  // --- set env var DIR_ROOT
  process.env.DIR_ROOT = dirRoot;
// --- Convert any simple file names in lFiles to full path
  for (j = 0, len1 = lFiles.length; j < len1; j++) {
    path = lFiles[j];
    if (isSimpleFileName(path)) {
      path = mkpath(dirRoot, path);
    }
  }
};

// ---------------------------------------------------------------------------
checkDir = function(key) {
  var dir;
  dir = process.env[key];
  if (dir && !fs.existsSync(dir)) {
    if (doDebug) {
      warn(`directory ${key} '${dir}' does not exist - removing`);
    }
    delete process.env[key];
  }
};

// ---------------------------------------------------------------------------
checkDirs = function() {
  var key;
  for (key in process.env) {
    if (key.match(/^DIR_/)) {
      checkDir(key);
    }
  }
};

// ---------------------------------------------------------------------------
main();
