package com.technotoil.image_videoeditor.camerafilter

enum class FilterId {
  NONE,
  SMOOTH_SKIN,
  BRIGHTEN_GLOW,
  SLIM_FACE,
  EYE_ENHANCE,
  LIPSTICK,
  LIPSTICK_RED,
  LIPSTICK_PINK,
  LIPSTICK_CORAL,
  LIPSTICK_PLUM,
  BIG_HEAD,
  FISHEYE_BULGE,
  OLD_AGE,
  BABY_FACE,
  DOG_EARS,
  CAT_EARS,
  FLOWER_CROWN,
  GLASSES,
  GLASSES_CLASSIC,
  GLASSES_SUN,
  GLASSES_RETRO,
  GLASSES_HEART,
  GLASSES_SPORT,
  FACE_SWAP,
  HAT,
  HAT_WIZARD,
  HAT_COWBOY,
  HAT_SANTA,
  SNAP_BUTTERFLIES,
  SNAP_NEON_OUTLINE,
  SNAP_NEON_NEON,
  SNAP_SUNSET_COWBOY,
  SNAP_ICY_DALMATIAN,
  SNAP_RETRO_BLOOM,
  SNAP_NOIR_KITTY,
  SNAP_EVIL_BW,
  SNAP_BOW_AESTHETIC,
  SNAP_DARK_MOON,
  SNAP_PINK_HEARTS,
  SNAP_DAY_STAMP,
  SNAP_CARTOON_TOON,
  SNAP_HEART_FRAME,
  SNAP_CITY_TIME,
  SNAP_POOKIE,
  SNAP_PANDA_FACE,
  SNAP_VINTAGE_GRAIN,
  SNAP_SPIDERMAN,
  SNAP_EYES_REVEAL,
  SNAP_WANTED_POSTER,
  SNAP_PINK_FLOWER,
  SNAP_RETRO_SKULL,
  SNAP_FASHION_OVERLAY,
  SNAP_TALKING_FOREST,
  SNAP_LENS_VERIFIED,
  SNAP_CREATOR_HUD,
  VINTAGE,
  BLACK_WHITE,
  VIBRANT,
  COOL_TONE,
  WARM_TONE;

  companion object {
    fun fromJs(value: String?): FilterId {
      return when (value) {
        "smoothSkin" -> SMOOTH_SKIN
        "brightenGlow" -> BRIGHTEN_GLOW
        "slimFace" -> SLIM_FACE
        "eyeEnhance" -> EYE_ENHANCE
        "lipstick" -> LIPSTICK
        "lipstick_red" -> LIPSTICK_RED
        "lipstick_pink" -> LIPSTICK_PINK
        "lipstick_coral" -> LIPSTICK_CORAL
        "lipstick_plum" -> LIPSTICK_PLUM
        "bigHead" -> BIG_HEAD
        "fisheyeBulge" -> FISHEYE_BULGE
        "oldAge" -> OLD_AGE
        "babyFace" -> BABY_FACE
        "dogEars" -> DOG_EARS
        "catEars" -> CAT_EARS
        "flowerCrown" -> FLOWER_CROWN
        "glasses" -> GLASSES_CLASSIC
        "glasses_classic" -> GLASSES_CLASSIC
        "glasses_sun" -> GLASSES_SUN
        "glasses_retro" -> GLASSES_RETRO
        "glasses_heart" -> GLASSES_HEART
        "glasses_sport" -> GLASSES_SPORT
        "faceSwap" -> FACE_SWAP
        "hat" -> HAT_WIZARD
        "hat_wizard" -> HAT_WIZARD
        "hat_cowboy" -> HAT_COWBOY
        "hat_santa" -> HAT_SANTA
        "snap_butterflies" -> SNAP_BUTTERFLIES
        "snap_neon_outline" -> SNAP_NEON_OUTLINE
        "snap_neon_neon" -> SNAP_NEON_NEON
        "snap_sunset_cowboy" -> SNAP_SUNSET_COWBOY
        "snap_icy_dalmatian" -> SNAP_ICY_DALMATIAN
        "snap_retro_bloom" -> SNAP_RETRO_BLOOM
        "snap_noir_kitty" -> SNAP_NOIR_KITTY
        "snap_evil_bw" -> SNAP_EVIL_BW
        "snap_bow_aesthetic" -> SNAP_BOW_AESTHETIC
        "snap_dark_moon" -> SNAP_DARK_MOON
        "snap_pink_hearts" -> SNAP_PINK_HEARTS
        "snap_day_stamp" -> SNAP_DAY_STAMP
        "snap_cartoon_toon" -> SNAP_CARTOON_TOON
        "snap_heart_frame" -> SNAP_HEART_FRAME
        "snap_city_time" -> SNAP_CITY_TIME
        "snap_pookie" -> SNAP_POOKIE
        "snap_panda_face" -> SNAP_PANDA_FACE
        "snap_vintage_grain" -> SNAP_VINTAGE_GRAIN
        "snap_spiderman" -> SNAP_SPIDERMAN
        "snap_eyes_reveal" -> SNAP_EYES_REVEAL
        "snap_wanted_poster" -> SNAP_WANTED_POSTER
        "snap_pink_flower" -> SNAP_PINK_FLOWER
        "snap_retro_skull" -> SNAP_RETRO_SKULL
        "snap_fashion_overlay" -> SNAP_FASHION_OVERLAY
        "snap_talking_forest" -> SNAP_TALKING_FOREST
        "snap_lens_verified" -> SNAP_LENS_VERIFIED
        "snap_creator_hud" -> SNAP_CREATOR_HUD
        "vintage" -> VINTAGE
        "blackWhite" -> BLACK_WHITE
        "vibrant" -> VIBRANT
        "coolTone" -> COOL_TONE
        "warmTone" -> WARM_TONE
        else -> NONE
      }
    }
  }
}
