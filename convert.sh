#!/usr/bin/env bash
# Ref. https://docs.ogc.org/bp/20-089r1.html#toc27

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
cd "${ORIG_DIR}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# the output directory is the starting directory (by convention)
OUTPUT_DIR="${ORIG_DIR}"

# main - entrypoint
main() {
  echo "Invocation args: $0 $@"
  fn="$1" && shift
  # switch on request function
  case "${fn}" in
    # resize image
    "resize" )
      resize "$@"
      ;;
    # else error
    * )
      echo "ERROR: Unknown function = ${fn}"
      return 1
      ;;
  esac
}

# function 'resize'
resize() {
  echo "resize with args: $@"
  srcType="$1" && shift
  # switch on the input type
  case "${srcType}" in
    # stac catalogue with image assets
    "--stac" )
      srcStac="$1" && shift
      resizeStac "${srcStac}" "$@"
      ;;
    # url to image
    "--url" )
      srcUrl="$1" && shift
      resizeUrl "${srcUrl}" "$@"
      ;;
    # else error
    * )
      echo "ERROR: Unknown source type = ${srcType}"
      return 1
      ;;
  esac
}

# resize from an input stac catalog
resizeStac() {
  echo "resizeStac: $@"
  dir="$1"
  size="$2"

  # get the name of the stac item file (first entry only - i.e. only single image supported)
  stacItemFile="$(cat "${dir}/catalog.json" | jq -r '[.links[] | select(.rel == "item")][0].href')"
  # ...and convert from relative to absolute path
  stacItemFileFull="${dir}/${stacItemFile}"

  # get the name of the first asset (only single image supported)
  inputFile="$(cat "${stacItemFileFull}" | jq -r 'first(.assets[]).href')"
  # ...and convert from relative to absolute path
  inputFileFull="$(dirname "${stacItemFileFull}")/${inputFile}"

  # invoke the resize on the resulting url
  resizeUrl "${inputFileFull}" "${size}"
}

# resize from an input url
resizeUrl() {
  echo "resizeUrl: $@"
  url="$1"
  size="$2"

  # deduce the filename, stem and extension
  filename="$(basename "${url}")"
  filestem="${filename%.*}"
  ext="${filename##*.}"
  # ...and use to construct the output filename
  outputFile="${filestem}-resize.${ext}"

  # use 'convert' (ImageMagick) to perform the resize
  convert "${url}" -resize "${size}" "${OUTPUT_DIR}/${outputFile}"

  # outputs as a stac catalogue
  createOutputStac "${outputFile}"
}

# create stac catalogue to represent the output file
createOutputStac() {
  outputFile="${1}"

  # gather inputs
  now="$(date +%s.%N)"
  mimetype="$(file -b --mime-type "${OUTPUT_DIR}/${outputFile}")"

  # create
  createStacItem "${now}" "${outputFile}" "${mimetype}"
  createStacCatalogRoot "${outputFile}"
}

# create the output stac item file
createStacItem() {
  now="${1}"
  filename="${2}"
  mimetype="${3}"

  # get the 'now' timestamp as an xml time representation
  dateNow="$(date -u --date=@${now} +%Y-%m-%dT%T.%03NZ)"
  # name of stac item file based on the name of the asset
  filestem="${filename%.*}"
  itemfile="${filestem}.json"

  # write the stac item file output, referencing the asset
  # see STAC item spec - https://github.com/radiantearth/stac-spec/blob/master/item-spec/item-spec.md
  cat - <<EOF > "${OUTPUT_DIR}/${itemfile}"
{
  "stac_version": "1.0.0",
  "id": "${filestem}-${now}",
  "type": "Feature",
  "geometry": {
    "type": "Polygon",
    "coordinates": [
      [
        [-180, -90],
        [-180, 90],
        [180, 90],
        [180, -90],
        [-180, -90]
      ]
    ]
  },
  "properties": {
    "created": "${dateNow}",
    "datetime": "${dateNow}",
    "updated": "${dateNow}"
  },
  "bbox": [-180, -90, 180, 90],
  "assets": {
    "output": {
      "type": "${mimetype}",
      "roles": ["data"],
      "href": "${filename}",
      "file:size": $(stat --printf="%s" "${OUTPUT_DIR}/${filename}")
    }
  },
  "links": [{
    "type": "application/json",
    "rel": "parent",
    "href": "catalog.json"
  }, {
    "type": "application/geo+json",
    "rel": "self",
    "href": "${itemfile}"
  }, {
    "type": "application/json",
    "rel": "root",
    "href": "catalog.json"
  }]
}
EOF
}

# create the stac root catalog file
createStacCatalogRoot() {
  filename="${1}"

  # name of stac item file based on the name of the asset
  filestem="${filename%.*}"
  itemfile="${filestem}.json"

  # write the stac root catalog file output, referencing the item file
  # see STAC catalog spec - https://github.com/radiantearth/stac-spec/blob/master/catalog-spec/catalog-spec.md
  cat - <<EOF > "${OUTPUT_DIR}/catalog.json"
{
  "stac_version": "1.0.0",
  "id": "catalog",
  "type": "Catalog",
  "description": "Root catalog",
  "links": [{
    "type": "application/geo+json",
    "rel": "item",
    "href": "${itemfile}"
  }, {
    "type": "application/json",
    "rel": "self",
    "href": "catalog.json"
  }]
}
EOF
}

# call the main entrypoint
main "$@"
