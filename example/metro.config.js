const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');
const pak = require('../package.json');

const escape = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const root = path.resolve(__dirname, '..');
const modules = Object.keys({ ...pak.peerDependencies });

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [root],
  resolver: {
    blockList: modules.map(
      (m) => new RegExp(`^${escape(path.join(root, 'node_modules', m))}\\/.*$`)
    ),
    extraNodeModules: modules.reduce((acc, name) => {
      acc[name] = path.join(__dirname, 'node_modules', name);
      return acc;
    }, {}),
    nodeModulesPaths: [
      path.resolve(__dirname, 'node_modules'),
      path.resolve(root, 'node_modules'),
    ],
    disableHierarchicalLookup: false,
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
