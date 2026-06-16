import React from 'react';
import { Image, ImageStyle, StyleProp } from 'react-native';
import { Base64Icons } from '../icons';

interface IconProps {
  name: keyof typeof Base64Icons;
  size: number;
  color?: string;
  style?: StyleProp<ImageStyle>;
}

export const Icon = ({ name, size, color, style }: IconProps) => {
  return (
    <Image 
      source={{ uri: Base64Icons[name] }} 
      style={[{ width: size, height: size, tintColor: color, resizeMode: 'contain' }, style]} 
    />
  );
};
