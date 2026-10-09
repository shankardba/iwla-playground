#!/bin/bash
# Usage: ./build.sh <public-base-url>   e.g. ./build.sh http://localhost:9100
set -e
BASE="${1:?base url required}"
cd "$(dirname "$0")"
THEMES=../wordpress/wp-content/themes
rm -f iwla-modern.zip
(cd "$THEMES" && zip -qr "$OLDPWD/iwla-modern.zip" iwla-modern -x "*/.git/*" "*/.DS_Store" "*.log")
python3 - "$BASE" <<'PY'
import json,sys
base=sys.argv[1].rstrip('/')
imgs={"rifle-pistol":"rifle-pistol.jpg","skeet-trap":"skeet-trap.jpg","archery":"archery.jpg","conservation":"conservation.jpg"}
steps=[{"step":"setSiteOptions","options":{"permalink_structure":"/%postname%/"}},
 {"step":"installTheme","themeData":{"resource":"url","url":base+"/iwla-modern.zip"},"options":{"activate":True}}]
steps.append({"step":"mkdir","path":"/wordpress/wp-content/iwla-media"})
for f in imgs.values():
    steps.append({"step":"writeFile","path":"/wordpress/wp-content/iwla-media/"+f,"data":{"resource":"url","url":base+"/media/"+f}})
php="""<?php
require '/wordpress/wp-load.php';
ob_start();
require get_theme_root() . '/iwla-modern/seed-content.php';
ob_end_clean();
require_once ABSPATH . 'wp-admin/includes/image.php';
$map = %s;
$up = wp_upload_dir();
$alts = array(
  'rifle-pistol' => 'Drone photo looking down the covered firing line at the Rifle & Pistol range, with the berm and target area beyond',
  'skeet-trap' => 'Drone photo looking down on the fan-shaped skeet and trap shooting stations, with the shot-fall field and tree line beyond',
  'archery' => 'A row of archery targets across a grass field, with the field archery gazebo on the right, framed by trees',
  'conservation' => 'A wooden bench overlooking the chapter pond on a clear winter day',
);
foreach ( $map as $slug => $file ) {
  $pages = get_posts( array( 'post_type' => 'page', 'name' => $slug, 'numberposts' => 1 ) );
  if ( ! $pages ) { continue; }
  $dest = $up['path'] . '/' . $file;
  copy( '/wordpress/wp-content/iwla-media/' . $file, $dest );
  $id = wp_insert_attachment( array( 'post_mime_type' => 'image/jpeg', 'post_title' => $slug . ' banner', 'post_status' => 'inherit' ), $dest, $pages[0]->ID );
  wp_update_attachment_metadata( $id, wp_generate_attachment_metadata( $id, $dest ) );
  if ( isset( $alts[ $slug ] ) ) { update_post_meta( $id, '_wp_attachment_image_alt', $alts[ $slug ] ); }
  set_post_thumbnail( $pages[0]->ID, $id );
}
flush_rewrite_rules();
""" % ("array(" + ",".join("'%s'=>'%s'"%(k,v) for k,v in imgs.items()) + ")")
steps.append({"step":"runPHP","code":php})
steps.append({"step":"login","username":"admin"})
bp={"$schema":"https://playground.wordpress.net/blueprint-schema.json","landingPage":"/","preferredVersions":{"php":"8.3","wp":"latest"},
    "siteOptions":{"blogname":"IWLA Arlington-Fairfax (test)"},"steps":steps}
json.dump(bp,open("blueprint.json","w"),indent=1)
PY
echo "built: $(du -h iwla-modern.zip | cut -f1) theme zip; blueprint.json -> $BASE"
