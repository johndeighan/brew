#!/usr/bin/env node
;
/*
	cielo [-h | -n | -e | -d ]
*/
var brewCieloFile, brewCoffeeFile, brewStarbucksFile, brewTamlFile, dirRoot, doWatch, envOnly, fixPath, main, output, parseCmdArgs, readySeen, removeFile, unlinkRelatedFiles;

import {
  strict as assert
} from 'assert';

import parseArgs from 'minimist';

import {
  parse as parsePath
} from 'path';

import {
  existsSync,
  statSync,
  unlinkSync
} from 'fs';

import chokidar from 'chokidar';

import {
  undef,
  croak,
  words
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
  newerDestFileExists
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

doWatch = true; // turn off with -n

envOnly = false; // set with -e

dirRoot = undef;

readySeen = false; // set true when 'ready' event is seen


// ---------------------------------------------------------------------------
main = function() {
  var watcher;
  parseCmdArgs();
  if (dirRoot == null) {
    dirRoot = process.cwd();
  }
  log(`ROOT: ${dirRoot}`);
  loadPrivEnvFrom(dirRoot);
  if (envOnly) {
    log(`DIR_ROOT = '${dirRoot}'`);
    logPrivEnv();
    process.exit();
  }
  watcher = chokidar.watch(dirRoot, {
    persistent: doWatch
  });
  watcher.on('all', function(event, path) {
    var ext, lMatches;
    if (event === 'ready') {
      readySeen = true;
      return;
    }
    if (path.match(/node_modules/) || (event === 'unlink')) {
      return;
    }
    if (lMatches = path.match(/\.(?:cielo|coffee|starbucks|taml)$/)) {
      log(`${event} ${fixPath(path)}`);
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
  if (!doWatch) {
    log("...not watching for further file changes");
  }
};

// ---------------------------------------------------------------------------
unlinkRelatedFiles = function(path, ext) {
  switch (ext) {
    case '.cielo':
      removeFile(path, '.coffee');
      break;
    case '.coffee':
      removeFile(path, '.js');
      break;
    case '.starbucks':
      removeFile(path, '.svelte');
      break;
    case '.taml':
      removeFile(path, '.js');
      break;
    default:
      croak(`Invalid file extension: '${ext}'`);
  }
};

// ---------------------------------------------------------------------------
removeFile = function(path, ext) {
  var filename;
  filename = withExt(path, ext);
  log(`   unlink ${filename}`);
  unlinkSync(filename);
};

// ---------------------------------------------------------------------------
brewCieloFile = function(srcPath) {
  var coffeeCode, destPath;
  // --- cielo => coffee
  destPath = withExt(srcPath, '.coffee');
  if (newerDestFileExists(srcPath, destPath)) {
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
  if (newerDestFileExists(srcPath, destPath)) {
    log("   dest exists");
    return;
  }
  jsCode = brewCoffee(slurp(srcPath));
  output(jsCode, srcPath, destPath);
};

// ---------------------------------------------------------------------------
brewStarbucksFile = function(srcPath) {
  var code, destPath, hOptions, hParsed;
  destPath = withExt(srcPath, '.svelte').replace('_', '');
  if (newerDestFileExists(srcPath, destPath)) {
    log("   dest exists");
    return;
  }
  hParsed = parsePath(srcPath);
  hOptions = {
    content: slurp(srcPath),
    filename: hParsed.base
  };
  code = starbucks(hOptions).code;
  output(code, srcPath, destPath);
};

// ---------------------------------------------------------------------------
brewTamlFile = function(srcPath) {
  var destPath, hParsed, srcDir, tamlCode;
  destPath = withExt(srcPath, '.js');
  if (newerDestFileExists(srcPath, destPath)) {
    log("   dest exists");
    return;
  }
  hParsed = parsePath(srcPath);
  srcDir = mkpath(hParsed.dir);
  if (srcDir !== hPrivEnv.DIR_STORES) {
    log(`   ${srcDir} is not ${hPrivEnv.DIR_STORES}`);
    return;
  }
  tamlCode = slurp(srcPath);
  output(`import {TAMLDataStore} from '@jdeighan/starbucks/stores'

export oz = new TAMLDataStore(\`${tamlCode}\`);`, srcPath, destPath);
};

// ---------------------------------------------------------------------------
output = function(code, srcPath, destPath) {
  barf(destPath, code);
  log(`   ${fixPath(srcPath)} => ${fixPath(destPath)}`);
};

// ---------------------------------------------------------------------------
parseCmdArgs = function() {
  var hArgs;
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('h n e d'),
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
  if (hArgs._ != null) {
    if (hArgs._.length === 1) {
      dirRoot = hArgs._[0];
    } else if (hArgs._.length > 1) {
      croak("Only one directory path allowed");
    }
  }
};

// ---------------------------------------------------------------------------
fixPath = function(path) {
  var _, lMatches, str, tail;
  // --- Replace user's home dir with '~'
  str = mkpath(path);
  if (lMatches = str.match(/^c:\/Users\/[a-z_][a-z0-9_]*\/(.*)$/i)) {
    [_, tail] = lMatches;
    return `~/${tail}`;
  } else {
    return str;
  }
};

// ---------------------------------------------------------------------------
main();
