#!/usr/bin/env node
;
/*
	cielo [-h | -n | -c | -d | -D ]
*/
var brewCieloFile, brewStarbucksFile, dirRoot, doWatch, fixPath, handleCmdArgs, main, output, saveCoffee;

import {
  strict as assert
} from 'assert';

import parseArgs from 'minimist';

import {
  parse as parsePath
} from 'path';

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
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  setDebugging,
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  loadEnvFrom
} from '@jdeighan/env';

import {
  starbucks
} from '@jdeighan/starbucks';

import {
  brewCielo
} from './brewCielo.js';

doWatch = true; // turn off with -n

saveCoffee = false;

dirRoot = undef;

// ---------------------------------------------------------------------------
main = function() {
  var watcher;
  handleCmdArgs();
  if (dirRoot == null) {
    dirRoot = process.cwd();
  }
  log(`ROOT: ${dirRoot}`);
  loadEnvFrom(dirRoot);
  watcher = chokidar.watch(dirRoot, {
    persistent: doWatch
  });
  watcher.on('all', function(event, path) {
    var ext, lMatches;
    if (path.match(/node_modules/) || (event === 'unlink')) {
      return;
    }
    if (lMatches = path.match(/\.(cielo|starbucks)$/)) {
      ext = lMatches[0];
      log(`${event} ${fixPath(path)}`);
      if (ext === '.cielo') {
        return brewCieloFile(path);
      } else if (ext === '.starbucks') {
        return brewStarbucksFile(path);
      } else {
        return croak(`Invalid file extension: '${ext}'`);
      }
    }
  });
};

// ---------------------------------------------------------------------------
brewCieloFile = function(path) {
  var coffeeCode, jsCode;
  [coffeeCode, jsCode] = brewCielo(slurp(path), 'both');
  if (saveCoffee) {
    output(coffeeCode, path, '.coffee');
  }
  output(jsCode, path, '.js');
};

// ---------------------------------------------------------------------------
brewStarbucksFile = function(path) {
  var code, hOptions, hParsed;
  hParsed = parsePath(path);
  hOptions = {
    content: slurp(path),
    filename: hParsed.base
  };
  code = starbucks(hOptions).code;
  output(code, path, '.svelte');
};

// ---------------------------------------------------------------------------
output = function(code, inpath, outExt) {
  var outpath;
  outpath = withExt(inpath, outExt);
  barf(outpath, code);
  log(`   ${fixPath(inpath)} => ${outExt}`);
};

// ---------------------------------------------------------------------------
handleCmdArgs = function() {
  var hArgs;
  hArgs = parseArgs(process.argv.slice(2), {
    boolean: words('h n c d'),
    unknown: function(opt) {
      return true;
    }
  });
  // --- Handle request for help
  if (hArgs.h) {
    log("cielo [ <dir> ]");
    log("   -h help");
    log("   -n process files, don't watch for changes");
    log("   -c save *.coffee file");
    log("   -d turn on debugging (a lot of output!)");
    log("<dir> defaults to current working directory");
    process.exit();
  }
  if (hArgs.n) {
    log("not watching for changes");
    doWatch = false;
  }
  if (hArgs.c) {
    log("saving coffee files");
    saveCoffee = true;
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
