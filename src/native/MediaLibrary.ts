import { NativeModules, Platform } from 'react-native';
import type { MediaItem, MediaType } from '../types';

export type Album = {
  id: string;
  title: string;
};

export type MediaQuery = {
  limit?: number;
  offset?: number;
  type?: MediaType | 'all';
  albumId?: string;
};

const { RNMediaLibrary } = NativeModules as {
  RNMediaLibrary?: {
    requestAccess: () => Promise<boolean>;
    listAlbums: () => Promise<Album[]>;
    listMedia: (query: MediaQuery) => Promise<MediaItem[]>;
    exportAsset: (localId: string) => Promise<string>;
    saveToGallery: (uri: string, type: string) => Promise<boolean>;
  };
};

export async function requestMediaAccess(): Promise<boolean> {
  if (!RNMediaLibrary?.requestAccess) {
    throw new Error(
      `RNMediaLibrary is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaLibrary.requestAccess();
}

export async function listAlbums(): Promise<Album[]> {
  if (!RNMediaLibrary?.listAlbums) {
    throw new Error(
      `RNMediaLibrary.listAlbums is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaLibrary.listAlbums();
}

export async function listMedia(query: MediaQuery): Promise<MediaItem[]> {
  if (!RNMediaLibrary?.listMedia) {
    throw new Error(
      `RNMediaLibrary.listMedia is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaLibrary.listMedia(query);
}

export async function exportAsset(localId: string): Promise<string> {
  if (!RNMediaLibrary?.exportAsset) {
    throw new Error(
      `RNMediaLibrary.exportAsset is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaLibrary.exportAsset(localId);
}

export async function saveToGallery(uri: string, type: string): Promise<boolean> {
  if (!RNMediaLibrary?.saveToGallery) {
    throw new Error(
      `RNMediaLibrary.saveToGallery is not available on ${Platform.OS}. Make sure the native module is linked.`
    );
  }
  return RNMediaLibrary.saveToGallery(uri, type);
}
