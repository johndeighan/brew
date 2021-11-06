#!/usr/bin/env node
;
var brewCieloFile, brewCoffeeFile, brewFile, brewStarbucksFile, brewTamlFile, checkDir, checkDirs, debugStarbucks, dirRoot, doDebug, doExec, doForce, doWatch, dumpOptions, dumpStats, envOnly, lFiles, main, nExecuted, nProcessed, needsUpdate, output, parseCmdArgs, quiet, readySeen, removeFile, saveAST, unlinkRelatedFiles;

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
  nonEmpty
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
  fileExt
} from '@jdeighan/coffee-utils/fs';

import {
  setDebugging,
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  hPrivEnv,
  logPrivEnv
} from '@jdeighan/coffee-utils/privenv';

import {
  loadPrivEnvFrom
} from '@jdeighan/env';

import {
  getNeededSymbols
} from '@jdeighan/string-input/coffee';

import {
  isTAML,
  taml
} from '@jdeighan/string-input/taml';

import {
  starbucks
} from '@jdeighan/starbucks';

import {
  brewCielo,
  brewCoffee
} from './brewCielo.js';

dirRoot = undef;

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

readySeen = false; // set true when 'ready' event is seen

nProcessed = 0;

nExecuted = 0;

// ---------------------------------------------------------------------------
main = function() {
  var ext, i, jsPath, len, path, watcher;
  parseCmdArgs();
  loadPrivEnvFrom(dirRoot);
  if (envOnly) {
    doDebug = true;
    checkDirs();
    logPrivEnv();
    process.exit();
  }
  checkDirs();
  if (doDebug) {
    logPrivEnv();
  }
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
brewFile = function(path) {
  var err;
  try {
    switch (fileExt(path)) {
      case '.cielo':
        brewCieloFile(path);
        break;
      case '.coffee':
        brewCoffeeFile(path);
        break;
      case '.starbucks':
        brewStarbucksFile(path);
        break;
      case '.taml':
        brewTamlFile(path);
        break;
      default:
        croak(`Unknown file type: ${path}`);
    }
  } catch (error) {
    err = error;
    log(`   FAILED: ${err.message}`);
  }
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
brewCieloFile = function(srcPath) {
  var coffeeCode, destPath;
  // --- cielo => coffee
  destPath = withExt(srcPath, '.coffee');
  if (needsUpdate(srcPath, destPath)) {
    coffeeCode = brewCielo(slurp(srcPath));
    output(coffeeCode, srcPath, destPath);
  }
};

// ---------------------------------------------------------------------------
brewCoffeeFile = function(srcPath) {
  var coffeeCode, destPath, dumpfile, i, jsCode, lNeeded, len, n, sym, word;
  // --- coffee => js
  destPath = withExt(srcPath, '.js', {
    removeLeadingUnderScore: true
  });
  if (needsUpdate(srcPath, destPath)) {
    coffeeCode = slurp(srcPath);
    if (saveAST) {
      dumpfile = withExt(srcPath, '.ast');
      lNeeded = getNeededSymbols(coffeeCode, {dumpfile});
      if ((lNeeded === undef) || (lNeeded.length === 0)) {
        log(`NO NEEDED SYMBOLS in ${shortenPath(destPath)}:`);
      } else {
        n = lNeeded.length;
        word = n === 1 ? 'SYMBOL' : 'SYMBOLS';
        log(`${n} NEEDED ${word} in ${shortenPath(destPath)}:`);
        for (i = 0, len = lNeeded.length; i < len; i++) {
          sym = lNeeded[i];
          log(`   - ${sym}`);
        }
      }
    }
    jsCode = brewCoffee(coffeeCode);
    output(jsCode, srcPath, destPath);
  }
};

// ---------------------------------------------------------------------------
brewStarbucksFile = function(srcPath) {
  var code, content, destPath, hOptions, hParsed;
  destPath = withExt(srcPath, '.svelte', {
    removeLeadingUnderScore: true
  });
  if (needsUpdate(srcPath, destPath)) {
    content = slurp(srcPath);
    if (debugStarbucks) {
      log(sep_eq);
      log(content);
      log(sep_eq);
    }
    hParsed = pathlib.parse(srcPath);
    hOptions = {
      content: content,
      filename: hParsed.base
    };
    code = starbucks(hOptions).code;
    if (debugStarbucks) {
      log(code);
      log(sep_eq);
    }
    output(code, srcPath, destPath);
  }
};

// ---------------------------------------------------------------------------
brewTamlFile = function(srcPath) {
  var destPath, hInfo, stub, tamlCode;
  destPath = withExt(srcPath, '.js', {
    removeLeadingUnderScore: true
  });
  if (needsUpdate(srcPath, destPath)) {
    hInfo = pathlib.parse(destPath);
    stub = hInfo.name;
    tamlCode = slurp(srcPath);
    output(`import {TAMLDataStore} from '@jdeighan/starbucks/stores';

export let ${stub} = new TAMLDataStore(\`${tamlCode}\`);`, srcPath, destPath);
  }
};

// ---------------------------------------------------------------------------
unlinkRelatedFiles = function(path, ext) {
  // --- file 'path' was removed
  switch (ext) {
    case '.cielo':
      removeFile(path, '.coffee');
      break;
    case '.coffee':
    case '.taml':
      if (path.indexOf('_') === -1) {
        removeFile(path, '.js');
      } else {
        removeFile(path, '.js', {
          removeLeadingUnderScore: true
        });
      }
      break;
    case '.starbucks':
      if (path.indexOf('_') === -1) {
        removeFile(path, '.svelte');
      } else {
        removeFile(path, '.svelte', {
          removeLeadingUnderScore: true
        });
      }
      break;
    default:
      croak(`Invalid file extension: '${ext}'`);
  }
};

// ---------------------------------------------------------------------------
removeFile = function(path, ext, hOptions = {}) {
  var err, fullpath;
  // --- file 'path' was removed
  //     remove same file, but with ext 'ext'
  //     valid options: same as withExt()
  fullpath = withExt(path, ext, hOptions);
  try {
    if (!quiet) {
      log(`   unlink ${filename}`);
    }
    fs.unlinkSync(fullpath);
  } catch (error) {
    err = error;
    log(`   FAILED: ${err.message}`);
  }
};

// ---------------------------------------------------------------------------
output = function(code, srcPath, destPath) {
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
dumpOptions = function() {
  log("OPTIONS:");
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
  var hArgs, i, j, len, len1, path, ref;
  // --- uses minimist
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('h n e d q f x D A'),
    unknown: function(opt) {
      return true;
    }
  });
  // --- Handle request for help
  if (hArgs.h) {
    log("cielo [ <dir> ]");
    log("   -h help");
    log("   -w process files, then watch for changes");
    log("   -e just display custom environment variables");
    log("   -d turn on some debugging");
    log("   -q quiet output (only errors)");
    log("   -f initially, process all files, even up to date");
    log("   -x execute *.cielo files on cmd line");
    log("   -s dump input & output from starbucks conversions");
    log("   -D turn on debugging (a lot of output!)");
    log("   -A save CoffeeScript abstract syntax trees");
    log("<dir> defaults to current working directory");
    process.exit();
  }
  if (hArgs.w) {
    doWatch = true;
  }
  if (hArgs.e) {
    envOnly = true;
  }
  if (hArgs.d) {
    doDebug = true;
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
  if (hArgs.s) {
    debugStarbucks = true;
  }
  if (!quiet) {
    dumpOptions();
  }
  if (hArgs.D) {
    setDebugging(true);
  }
  if (hArgs._ != null) {
    ref = hArgs._;
    for (i = 0, len = ref.length; i < len; i++) {
      path = ref[i];
      if (path.indexOf('.') === 0) {
        // --- relative path - convert to absolute
        path = getFullPath(path); // converts \ to /
      } else {
        path = mkpath(path); // convert \ to /
      }
      if (isDir(path)) {
        assert(!dirRoot, "multiple dirs not allowed");
        dirRoot = path;
        if (!quiet) {
          log(`DIR_ROOT: ${dirRoot} (from cmd line)`);
        }
      } else if (isFile(path)) {
        lFiles.push(path);
      } else {
        croak(`Invalid path '${path}' on command line`);
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
  dir = hPrivEnv[key];
  if (dir && !fs.existsSync(dir)) {
    if (doDebug) {
      warn(`directory ${key} '${dir}' does not exist - removing`);
    }
    delete hPrivEnv[key];
  }
};

// ---------------------------------------------------------------------------
checkDirs = function() {
  var key;
  for (key in hPrivEnv) {
    if (key.match(/^DIR_/)) {
      checkDir(key);
    }
  }
};

// ---------------------------------------------------------------------------
main();
