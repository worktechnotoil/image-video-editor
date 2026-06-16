const fs = require('fs');
const https = require('https');

const icons = {
  play: 'play',
  pause: 'pause',
  'arrow-undo': 'undo',
  'arrow-redo': 'redo',
  close: 'delete-sign',
  text: 'type',
  'musical-notes': 'music',
  crop: 'crop',
  'crop-outline': 'crop',
  'color-palette': 'paint-palette',
  images: 'image',
  'settings-outline': 'settings',
  'volume-mute': 'mute',
  'volume-high': 'speaker',
  cut: 'cut',
  'arrow-forward': 'forward',
  'close-circle': 'cancel',
  trash: 'trash',
  'trash-outline': 'trash',
  checkmark: 'checkmark',
  'chevron-down': 'expand-arrow',
  'camera-reverse-outline': 'switch-camera',
  'square-outline': 'unchecked-checkbox',
  'expand-outline': 'fit-to-width',
  'flash': 'flash-on',
  'flash-off': 'flash-off'
};

const result = {};

async function fetchAll() {
  for (const [key, name] of Object.entries(icons)) {
    await new Promise((resolve) => {
      https.get(`https://img.icons8.com/ios-glyphs/90/ffffff/${name}.png`, (res) => {
        const data = [];
        res.on('data', chunk => data.push(chunk));
        res.on('end', () => {
          result[key] = 'data:image/png;base64,' + Buffer.concat(data).toString('base64');
          console.log('Fetched', key);
          resolve();
        });
      });
    });
  }
  
  const content = `export const Base64Icons = ${JSON.stringify(result, null, 2)};\n`;
  fs.writeFileSync('src/icons.ts', content);
  console.log('Saved to src/icons.ts');
}

fetchAll();
