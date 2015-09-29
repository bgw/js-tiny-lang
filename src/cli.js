import fs from 'fs';
import Promise from 'bluebird';
import util from 'util';
import yargs from 'yargs';

import grammar from './grammar';

Promise.longStackTraces();

let argv = yargs.usage('$0 <command>')
  .command('parse', 'generate and print an AST in JSON format')
  .command('compile', 'generate a js file from a tiny file')
  .command('exec', 'compile and run the tiny file')
  .demand(1, 'must provide valid action')
  .help('help')
  .argv;

const command = argv._[0];
yargs.reset();
switch (command) {
  case 'parse':
    argv = yargs.usage('$0 parse [input] [output]')
      .string('_').demand(1, 3)
      .describe('_', 'defaults to stdin/stdout')
      .alias('location', 'l')
      .boolean('location')
      .describe('location', 'include location metadata in the tree')
      .help('help')
      .argv
    const [input, output] = [getInput(argv._[1]), getOutput(argv._[2])];
    readStream(input)
      .then((inputString) => {
        output.write(util.inspect(
          grammar.parse(inputString, {location: argv.location}),
          {showHidden: false, depth: null}
        ));
        output.write('\n');
      })
    break;
  default:
    yargs.showHelp();
}

function getInput(path) {
  return path ? fs.createReadStream(path) : process.stdin;
}
function getOutput(path) {
  return path ? fs.createWriteStream(path) : process.stdout;
}

// read an *entire* stream, and return a promise
function readStream(stream) {
  return new Promise((resolve, reject) => {
    let data = [];
    stream.on('readable', () => {
      const chunk = stream.read('utf-8');
      if (chunk != null) {
        data.push(chunk);
      }
    });
    stream.on('error', reject);
    stream.on('end', () => resolve(data.join('')));
  });
}

Promise.onPossiblyUnhandledRejection(function(error) {
  if (error instanceof grammar.SyntaxError) {
    const loc = error.location.start;
    console.error(`Syntax error on line ${loc.line}, column ${loc.column}`);
  }
  throw error;
});
