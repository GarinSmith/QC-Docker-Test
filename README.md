- [`convert` - Example Application Package](#convert---example-application-package)
  - [Application Implementation - `convert.sh`](#application-implementation---convertsh)
    - [Outputs](#outputs)
    - [`resize --url` implementation](#resize---url-implementation)
    - [`resize --stac` implementation](#resize---stac-implementation)
  - [Application Container Image - `eoepca/convert`](#application-container-image---eoepcaconvert)
  - [Application CWL](#application-cwl)
    - [`CommandLineTool`](#commandlinetool)
    - [`Workflow`](#workflow)
  - [Local Execution](#local-execution)
    - [local: `resize --url`](#local-resize---url)
    - [local: `resize --stac`](#local-resize---stac)
  - [ADES Execution](#ades-execution)
    - [Deploy Application (`--url`)](#deploy-application---url)
    - [Execute Application (`--url`)](#execute-application---url)
    - [Deploy Application (`--stac`)](#deploy-application---stac)
    - [Execute Application (`--stac`)](#execute-application---stac)

# `convert` - Example Application Package

This repo provides a simple example Application Package in accordance with the [OGC Best Practice for Application Packages](https://docs.ogc.org/bp/20-089r1.html).

The `convert` application package comprises these parts:
* Application Implementation<br>
  A `bash` script (`convert.sh`) that implements the application functionality
* Application Container Image<br>
  A docker container image that packages the convert script
* Application CWL<br>
  A CWL file that describes the application so that it can be deployed and executed in an OGC API Processes service

## Application Implementation - `convert.sh`

The script is a wrapper around the `convert` utility from [ImageMagick](https://imagemagick.org/). The script implements a resize function that takes an image as input, and outputs a resized version of the image.

`convert.sh` takes the following command-line arguments...

```
Usage: convert.sh <function>
where,
  <function>  The operation to perform - currently only `resize` is supported

Usage: convert.sh resize [--url <url> | --stac <stac-catalog>] <size>
where,
  <url>           The url to the input image - http/https or file-system path
  <stac-catalog>  Directory containing a STAC catalog - root file `catalog.json`.
                  The first asset in the first stac item is used as the input.
  <size>          The amount to resize = e.g. `50%`

  `--url` and `--stac` are mutually exclusive - exactly one must be supplied.
```

### Outputs

The 'current working directory' of the application execution is the directory into which all outputs must be placed by the application. This location is established by the CWL runner, and is consistent with the approach defined by the OGC Best Practice.

The convert.sh script names the resized output file by reusing the name of the input file with the postfix `-resize`.

The outputs must be presented as a STAC catalog. Thus, the application must accompany the output image with STAC catalog and item files that reference the image asset.

### `resize --url` implementation

The `resize --url` operation is performed by directly invoking the convert utility with the supplied url and size. For example...

```
convert https://eoepca.org/media_portal/images/logo6_med.original.png 50%
```

### `resize --stac` implementation

In this case the argument supplied as `--stac <stac-catalog>` is an input directory within which it is expected to find a static STAC catalogue. The file `<stac-catalog>/catalog.json` is expected to exist, from where the input asset can be discovered. For simplicity, the first asset in the first STAC item is taken.

Once the input image has been identified then the convert utility is invoked similarly as for the --url case. For example...

```
convert <stac-catalog>/eoepca-logo.png 50%
```

## Application Container Image - `eoepca/convert`

The application script `convert.sh` is packaged into a container image, along with its dependencies.

Dockerfile...
```
FROM ubuntu
RUN apt-get update && apt-get -y install curl imagemagick file jq
WORKDIR /app
COPY ./convert.sh /app
ENV PATH="/app:${PATH}"
```

## Application CWL

In accordance with the OGC Best Practice, the application is described by a CWL file.

The CWL application description comprises two parts:
* CommandLineTool<br>
  Describes the tool to be executed - `convert.sh` is this case
* Workflow<br>
  Provides the entry-point to the application package, in accordance with the OGC Best Practice

Two variants of the Application Package are provided to reflect use of either `--url` or `--stac` - ref. [`convert-url-app.cwl`](convert-url-app.cwl) and [`convert-stac-app.cwl`](convert-stac-app.cwl).

> It would be possible to express these exclusive inputs in a single application package (ref. [records and type unions](https://www.commonwl.org/user_guide/topics/inputs.html#inclusive-and-exclusive-inputs)) - but for simplicity separate application packages are used.

### `CommandLineTool`

Describes the convert.sh script in terms of its inputs as command-line arguments, and outputs.

Example for `--url`...

```
  - class: CommandLineTool
    id: convert
    baseCommand: convert.sh
    inputs:
      fn:
        type: string
        inputBinding:
          position: 1
      url:
        type: string
        inputBinding:
          position: 2
          prefix: --url
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
```

The `baseCommand` is required to identify the 'executable' to invoke - assumed to be on the `PATH` within the container environment.

The `inputs` reflect the stated command-line options for `<function>`, `<url>` (with prefix) and `<size>` - all of type `string`.

The `outputs` are all files in the output directory.

The application container image for execution is identified as `eoepca/convert:latest`.

The `CommandLineTool` for `--stac` varies only by replacing the `url` input with the `stac` input, which is of type `Directory`...

```
      stac:
        type: Directory
        inputBinding:
          position: 2
          prefix: --stac
```

### `Workflow`

Provides the entry-point to the application package, and includes the step to invoke `convert.sh` via the defined `CommandLineTool`.

Example for `--url`...

```
  - class: Workflow
    doc: Convert URL
    id: convert-url
    label: convert url app
    inputs:
      fn:
        type: string
      url:
        type: string
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
          url: url
          size: size
        out:
          - results
```

The workflow matches the inputs of the `convert.sh` script, which are passed through to the `CommandLineTool`.

The workflow has a single step, which is the invocation of `convert` - the outputs of which are mapped as a the outputs of the workflow.

As before, the `Workflow` for `--stac` varies only by replacing the `url` input with the `stac` input, which is of type `Directory`...

```
      stac:
        type: Directory
```

Signficantly, this input of type `Directory`, which triggers the ADES to perform a `stage-in` of the inputs from the identified source.

During stage-in the ADES interprets the source, retrieves the identified assets and presents them as a STAC catalog in an input directory for the executing application.

The ADES understands a variety of sources, such as OpenSearch URLs, which it is able to use as a source of assets and 'transform' to a local STAC catalog for application input.

In the simplest case, the source can be provided as an existing STAC catalog, or even a single STAC item.

## Local Execution

For testing and experimentation, the application package can be executed locally using `cwltool`.

### local: `resize --url`

```
cwltool --outdir out convert-url-app.cwl#convert \
  --fn resize \
  --url "https://eoepca.org/media_portal/images/logo6_med.original.png" \
  --size "50%"
```

### local: `resize --stac`

```
cwltool --outdir out convert-stac-app.cwl#convert \
  --fn resize \
  --stac ./stac \
  --size "50%"
```

> NOTE<br>
> Since the application package is executed outside the context of the ADES stage-in functionality, the `--stac` must be provided as 'pre-staged-in' STAC catalog directory.<br>
> For this purpose, a simple STAC catalogue has been created in the [`stac/`](stac/) directory of this repository.

## ADES Execution

The application package can be deployed and executed on an ADES instance.

> See also the [Deployment Guide Quick Example](https://deployment-guide.docs.eoepca.org/current/quickstart/quickstart/#quick-example) for more context.

### Deploy Application (`--url`)

```
curl --request POST \
  --url https://ades-open.<domain>/<user>/wps3/processes \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --data '{"executionUnit": {"href": "https://raw.githubusercontent.com/EOEPCA/convert/main/convert-url-app.cwl","type": "application/cwl"}}'
```

### Execute Application (`--url`)

```
curl --request POST \
  --url https://ades-open.<domain>/<user>/wps3/processes/convert-url-0_1_1/execution \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'prefer: respond-async' \
  --data '{"inputs": {"fn": "resize","url":  "https://eoepca.org/media_portal/images/logo6_med.original.png","size": "50%"},"response":"raw"}'
```

### Deploy Application (`--stac`)

```
curl --request POST \
  --url https://ades-open.<domain>/<user>/wps3/processes \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --data '{"executionUnit": {"href": "https://raw.githubusercontent.com/EOEPCA/convert/main/convert-stac-app.cwl","type": "application/cwl"}}'
```

### Execute Application (`--stac`)

Demonstration of ADES invocation with inputs as _STAC catalog_ and alternatively as _STAC item_ - noting that, after ADES stage-in, the application will always receive a STAC catalog as input.

**Input as STAC catalog...**

```
curl --request POST \
  --url https://ades-open.<domain>/<user>/wps3/processes/convert-stac-0_1_1/execution \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'prefer: respond-async' \
  --data '{"inputs": {"fn": "resize","stac":  "https://raw.githubusercontent.com/EOEPCA/convert/main/stac/catalog.json","size": "50%"},"response":"raw"}'
```

> NOTE input STAC item [`catalog.json`](stac/catalog.json)

**Input as STAC item...**

```
curl --request POST \
  --url https://ades-open.<domain>/<user>/wps3/processes/convert-stac-0_1_1/execution \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'prefer: respond-async' \
  --data '{"inputs": {"fn": "resize","stac":  "https://raw.githubusercontent.com/EOEPCA/convert/main/stac/eoepca-logo.json","size": "50%"},"response":"raw"}'
```

> NOTE input STAC item [`eoepca-logo.json`](stac/eoepca-logo.json)
