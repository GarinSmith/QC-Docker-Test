cwlVersion: v1.0
$namespaces:
  s: https://schema.org/
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf
s:softwareVersion: 0.1.1

$graph:
  # Workflow entrypoint
  - class: Workflow
    doc: Convert Stac
    id: convert-stac
    label: convert stac app
    inputs:
      fn:
        type: string
      stac:
        type: Directory
      size:
        type: string
    outputs:
      - id: wf_outputs
        type: Directory
        outputSource:
          - convert/results
    steps:
      convert:
        run: "#convert"
        in:
          fn: fn
          stac: stac
          size: size
        out:
          - results

  # convert.sh - takes input args `--stac`
  - class: CommandLineTool
    id: convert
    baseCommand: convert.sh
    inputs:
      fn:
        type: string
        inputBinding:
          position: 1
      stac:
        type: Directory
        inputBinding:
          position: 2
          prefix: --stac
      size:
        type: string
        inputBinding:
          position: 3
    outputs:
      results:
        type: Directory
        outputBinding:
          glob: .
    requirements:
      DockerRequirement:
        dockerPull: eoepca/convert:latest
