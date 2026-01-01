#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import { build } from '../commands/build.js';
import { composerInstall } from '../commands/composer-install.js';
import { networkFix } from '../commands/network-fix.js';

const program = new Command();

program
  .name('dapp-bk-node')
  .description('Docker App Build Kit - Docker container management toolkit')
  .version('1.0.0');

program
  .command('build')
  .description('Build and manage Docker containers for your application')
  .option('--rebuild-app', 'Rebuild the application container')
  .option('--rebuild-data', 'Rebuild the data container')
  .option('--import-data', 'Import data into the database container')
  .action(build);

program
  .command('composer:install')
  .description('Install Composer dependencies in the app container')
  .action(composerInstall);

program
  .command('network:fix')
  .description('Fix Docker network issues')
  .action(networkFix);

program.parse();
