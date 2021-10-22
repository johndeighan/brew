#!/usr/bin/env node
;
/*
	cielo [-h | -n | -e | -d | -f | -D ] [ <files or directory> ]
*/
var brewCieloFile, brewCoffeeFile, brewFile, brewStarbucksFile, brewTamlFile, checkDir, checkDirs, debugStarbucks, dirRoot, doForce, doWatch, envOnly, lFiles, main, output, parseCmdArgs, readySeen, removeFile, unlinkRelatedFiles;

import parseArgs from 'minimist';

import pathlib from 'path';

import fs from 'fs';

import chokidar from 'chokidar';

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
  isSimpleFileName
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

doForce = false; // turn on with -f

doWatch = true; // turn off with -n

envOnly = false; // set with -e

debugStarbucks = false; // set with -D

readySeen = false; // set true when 'ready' event is seen


// ---------------------------------------------------------------------------
main = function() {
  var i, len, path, watcher;
  parseCmdArgs();
  log(`DIR_ROOT: ${dirRoot}`);
  loadPrivEnvFrom(dirRoot);
  checkDirs();
  logPrivEnv();
  if (envOnly) {
    process.exit();
  }
  if (nonEmpty(lFiles)) {
// --- Process only these files
    for (i = 0, len = lFiles.length; i < len; i++) {
      path = lFiles[i];
      brewFile(path);
    }
    process.exit();
  }
  watcher = chokidar.watch(dirRoot, {
    persistent: doWatch
  });
  watcher.on('all', function(event, path) {
    var ext, lMatches;
    if (event === 'ready') {
      readySeen = true;
      if (doWatch) {
        log("...watching for further file changes");
      } else {
        log("...not watching for further file changes");
      }
      return;
    }
    if (path.match(/node_modules/)) {
      return;
    }
    if (lMatches = path.match(/\.(?:cielo|coffee|starbucks|taml)$/)) {
      log(`${event} ${shortenPath(path)}`);
      ext = lMatches[0];
      if (event === 'unlink') {
        unlinkRelatedFiles(path, ext);
      } else {
        switch (ext) {
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
            croak(`Invalid file extension: '${ext}'`);
        }
      }
    }
  });
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
        removeFile(path.replace('_', ''), '.js');
      }
      break;
    case '.starbucks':
      if (path.indexOf('_') === -1) {
        removeFile(path, '.svelte');
      } else {
        removeFile(path.replace('_', ''), '.svelte');
      }
      break;
    default:
      croak(`Invalid file extension: '${ext}'`);
  }
};

// ---------------------------------------------------------------------------
removeFile = function(path, ext) {
  var fullpath;
  // --- file 'path' was removed
  //     remove same file, but with ext 'ext'
  fullpath = withExt(path, ext);
  try {
    fs.unlinkSync(fullpath);
    log(`   unlink ${filename}`);
  } catch (error) {}
};

// ---------------------------------------------------------------------------
brewFile = function(srcPath) {
  var ext, lMatches;
  if (lMatches = srcPath.match(/\.(?:cielo|coffee|starbucks|taml)$/)) {
    log(`brew ${shortenPath(srcPath)}`);
    ext = lMatches[0];
    switch (ext) {
      case '.cielo':
        brewCieloFile(srcPath);
        break;
      case '.coffee':
        brewCoffeeFile(srcPath);
        break;
      case '.starbucks':
        brewStarbucksFile(srcPath);
        break;
      case '.taml':
        brewTamlFile(srcPath);
        break;
      default:
        croak(`Invalid file extension: '${ext}'`);
    }
  } else {
    croak(`Unknown file type: ${srcPath}`);
  }
};

// ---------------------------------------------------------------------------
brewCieloFile = function(srcPath) {
  var coffeeCode, destPath;
  // --- cielo => coffee
  destPath = withExt(srcPath, '.coffee');
  if (newerDestFileExists(srcPath, destPath) && readySeen) {
    log("   dest exists");
    return;
  }
  coffeeCode = brewCielo(slurp(srcPath));
  output(coffeeCode, srcPath, destPath);
};

// ---------------------------------------------------------------------------
brewCoffeeFile = function(srcPath) {
  var destPath, jsCode;
  // --- coffee => js
  destPath = withExt(srcPath, '.js').replace('_', '');
  if (newerDestFileExists(srcPath, destPath) && readySeen) {
    log("   dest exists");
    return;
  }
  jsCode = brewCoffee(slurp(srcPath));
  output(jsCode, srcPath, destPath);
};

// ---------------------------------------------------------------------------
brewStarbucksFile = function(srcPath) {
  var code, content, destPath, hOptions, hParsed;
  destPath = withExt(srcPath, '.svelte').replace('_', '');
  if (newerDestFileExists(srcPath, destPath) && readySeen) {
    log("   dest exists");
    return;
  }
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
};

// ---------------------------------------------------------------------------
brewTamlFile = function(srcPath) {
  var destPath, envDir, hInfo, hParsed, srcDir, stub, tamlCode;
  destPath = withExt(srcPath, '.js').replace('_', '');
  if (newerDestFileExists(srcPath, destPath) && readySeen) {
    log("   dest exists");
    return;
  }
  hParsed = pathlib.parse(srcPath);
  srcDir = mkpath(hParsed.dir);
  envDir = hPrivEnv.DIR_STORES;
  assert(envDir, "DIR_STORES is not set!");
  if (srcDir !== envDir) {
    log(`   ${srcDir} is not ${envDir}`);
    return;
  }
  hInfo = pathlib.parse(destPath);
  stub = hInfo.name;
  tamlCode = slurp(srcPath);
  output(`import {TAMLDataStore} from '@jdeighan/starbucks/stores';

export let ${stub} = new TAMLDataStore(\`${tamlCode}\`);`, srcPath, destPath);
};

// ---------------------------------------------------------------------------
output = function(code, srcPath, destPath) {
  var err;
  try {
    barf(destPath, code);
  } catch (error) {
    err = error;
    log(`ERROR: ${err.message}`);
  }
  log(`   ${shortenPath(srcPath)} => ${shortenPath(destPath)}`);
};

// ---------------------------------------------------------------------------
parseCmdArgs = function() {
  var hArgs, i, j, len, len1, path, ref;
  // --- uses minimist
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('h n e d f D'),
    unknown: function(opt) {
      return true;
    }
  });
  // --- Handle request for help
  if (hArgs.h) {
    log("cielo [ <dir> ]");
    log("   -h help");
    log("   -n process files, don't watch for changes");
    log("   -e just display custom environment variables");
    log("   -d turn on debugging (a lot of output!)");
    log("   -f initially, process all files, even up to date");
    log("   -D dump input & output from starbucks conversions");
    log("<dir> defaults to current working directory");
    process.exit();
  }
  if (hArgs.n) {
    doWatch = false;
  }
  if (hArgs.e) {
    envOnly = true;
  }
  if (hArgs.d) {
    log("extensive debugging on");
    setDebugging(true);
  }
  if (hArgs.f) {
    doForce = true;
  }
  if (hArgs.D) {
    log("debugging starbucks conversions");
    debugStarbucks = true;
  }
  if (hArgs._ != null) {
    ref = hArgs._;
    for (i = 0, len = ref.length; i < len; i++) {
      path = ref[i];
      path = mkpath(path); // convert \ to /
      if (isDir(path)) {
        assert(!dirRoot, "multiple dirs not allowed");
        dirRoot = path;
      } else if (isFile(path)) {
        lFiles.push(path);
      } else {
        croak(`Invalid path '${path}' on command line`);
      }
    }
  }
  if (!dirRoot) {
    if (process.env.DIR_ROOT) {
      dirRoot = mkpath(process.env.DIR_ROOT);
    } else {
      dirRoot = process.env.DIR_ROOT = mkpath(process.cwd());
    }
  }
// --- Convert any simple file names in lFiles to full path
  for (j = 0, len1 = lFiles.length; j < len1; j++) {
    path = lFiles[j];
    if (isSimpleFileName(path)) {
      path = mkpath(dirRoot, path);
    }
  }
};

// ---------------------------------------------------------------------------
checkDir = function(name) {
  var dir;
  dir = hPrivEnv[name];
  if (dir && !fs.existsSync(dir)) {
    warn(`directory ${dir} does not exist - removing`);
    delete hPrivEnv[name];
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
