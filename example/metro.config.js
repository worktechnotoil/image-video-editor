const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');
const pack = require('../package.json');

const root = path.resolve(__dirname, '..');
const peerDeps = Object.keys(pack.peerDependencies || {});

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const defaultConfig = getDefaultConfig(__dirname);

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [root],
  resolver: {
    blockList: [
      ...peerDeps.map(
        (m) => new RegExp(`^${escapeRegExp(path.resolve(root, 'node_modules', m))}(/.*)?$`)
      ),
    ],
    extraNodeModules: peerDeps.reduce(
      (acc, name) => {
        acc[name] = path.resolve(__dirname, 'node_modules', name);
        return acc;
      },
      {
        '@technotoil/image-video-editor': root,
      }
    ),
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
  },
};

module.exports = mergeConfig(defaultConfig, config);
