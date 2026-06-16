const fs = require('fs');
const https = require('https');

const icons = {
  'crop-outline': 'crop',
  'square-outline': 'unchecked-checkbox',
  'expand-outline': 'fit-to-width',
  'flash': 'flash-on',
  'flash-off': 'flash-off'
};

const result = require('./src/icons.js') || {}; // Wait, icons.ts is TS.

