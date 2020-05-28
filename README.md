# Heroku Buildpack R Build - [Second Edition][build2]

![CI](https://github.com/virtualstaticvoid/heroku-buildpack-r-build2/workflows/CI/badge.svg)

Build for the [heroku-buildpack-r][buildpack] buildpack.

## Prerequisites

* You need a [GitHub account][signup]
* Make
* Docker
* Access to Docker Hub for the [`ubuntu:*`][dhubuntu] and [`heroku/heroku:*`][dhheroku] docker images
* [AWS Account][aws]
* AWS [cli][awscli] installed
* AWS credentials configured as per [Standardized Way to Manage Credentials][awscreds]
* Access to S3 and a provisioned bucket
* [Heroku Account][heroku]

## Usage

To build, test and publish artifacts for the buildpack:

```
make build
make test
make publish
```

### Variables

The following build variables are available:

| Variable             | Default      | Notes   |
|----------------------|--------------|---------|
| `HEROKU_STACK`       | 20           | Corresponds to numeric suffix of the [Heroku Stack][heroku_stack]. Valid values include `18` and `20`. |
| `UBUNTU_IMAGE`       | ubuntu:20.04 | The docker image for the Ubuntu image. Should correspond with the Ubuntu version of the Heroku Stack. |
| `R_VERSION`          | 4.1.2        | The version of R to be built. |
| `CRAN_VERSION`       | cran40       | The CRAN repository version. |
| `BUILDPACK_VERSION`  | latest       | Version of the buildpack. This maps to the directory used on S3. Valid values include at least `latest` and `test`. |

E.g. To build for the `heroku-16` stack

```
export HEROKU_STACK=16
make build
make test
make publish
```

## Credits

* Original [virtualstaticvoid/heroku-buildpack-r-build][build1] repository.
* Build snippets from the [rstudio/r-builds][rbuilds] project.
* Test snippets from the [rstudio/r-docker][rdocker] project.

## License

MIT License. Copyright (c) 2020 Chris Stefano. See [LICENSE](LICENSE) for details.

[aws]: https://portal.aws.amazon.com/billing/signup#/start
[awscli]: https://aws.amazon.com/cli/
[awscreds]: https://aws.amazon.com/blogs/security/a-new-and-standardized-way-to-manage-credentials-in-the-aws-sdks
[build1]: https://github.com/virtualstaticvoid/heroku-buildpack-r-build
[build2]: https://github.com/virtualstaticvoid/heroku-buildpack-r-build2
[buildpack]: https://github.com/virtualstaticvoid/heroku-buildpack-r
[dhheroku]: https://hub.docker.com/r/heroku/heroku/tags
[dhubuntu]: https://hub.docker.com/_/ubuntu
[heroku]: https://signup.heroku.com
[heroku_stack]: https://devcenter.heroku.com/articles/stack
[rbuilds]: https://github.com/rstudio/r-builds
[rdocker]: https://github.com/rstudio/r-docker
[signup]: https://github.com/signup/free
