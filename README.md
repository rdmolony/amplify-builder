# Aws Amplify Build Image

- [Aws Amplify Build Image](#aws-amplify-build-image)
  - [Install](#install)
  - [Build \& Deploy Image](#build--deploy-image)
    - [Authenticate with `AWS`](#authenticate-with-aws)
    - [Create a Public ECR Repository](#create-a-public-ecr-repository)
    - [Build](#build)
    - [Deploy](#deploy)
    - [Test it](#test-it)
      - [Run a shell in the image](#run-a-shell-in-the-image)
      - [Fetch a package from `<nixpkgs>`](#fetch-a-package-from-nixpkgs)
      - [Run a nix flake application](#run-a-nix-flake-application)
      - [Fetch a nix flake from `GitHub` and run it](#fetch-a-nix-flake-from-github-and-run-it)


---

## Install

- Install `nix` via [DeterminateSystems/nix-installer](https://github.com/DeterminateSystems/nix-installer) or ...

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
```

- Run ...

```sh
nix develop
```

... to build & activate this developer environment

- (Optional) Install `direnv` via [nix-community/nix-direnv](https://github.com/nix-community/nix-direnv) **to activate this environment automatically on `cd`'ing to this directory**

- Install [`podman`](https://podman.io/docs/installation) or [`docker`](https://docs.docker.com/engine/install/) **to deploy the image to a container store**

> [!NOTE]
> On `NixOS`, I had to install `docker` globally since otherwise `docker` complained with ...
> ```sh
> Cannot connect to the Docker daemon at unix:///var/run/docker.> sock. Is the docker daemon running?
> ```
>
> Note that this might not be an issue for podman

---

## Build & Deploy Image


### Authenticate with `AWS`

- Create a `.env` file

```sh
cp .env.example .env
```

- Authenticate with AWS
  
  - [Via environment variables](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-envvars.html)

    - Go to your AWS user portal
    - Copy & paste environment variables from your `AccessKeys` into your `.env` file

  - Or [via sso](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)

    - Connect your machine to AWS once-off via the AWS CLI
    - Copy & paste the generated `AWS_PROFILE` into your `.env` file
    - Run `aws sso login` to authenticate with AWS 

- Activate the environment variables (or run this automatically if `direnv` is installed) ...

  ```sh
  source .env
  ```

### Create a Public ECR Repository


- Authenticate with `AWS` ...

```sh
aws ecr-public get-login-password --region us-east-1 | podman login --username AWS --password-stdin public.ecr.aws
```

- Create a public repository ...

```sh
aws ecr-public create-repository \
  --repository-name amplify-builder \
  --region us-east-1
```

- (Optional) Request repository alias `powerscope` in the `AWS` console, so I can use `public.ecr.aws/powerscope` instead of the default alias `public.ecr.aws/x2l1o5j9` to reference the repository


---

### Build

> [!NOTE]
> You can replace `podman` in any of the following commands with `docker` if that's what you've installed!

- Build it via `nix` ...

```sh
nix build
```

- Load it & tag it ...

```sh
export IMAGE_FULL=$(podman image load -i result)
export IMAGE_NAME=$(echo $IMAGE_FULL | awk -F'/' '{print $2}' | awk -F':' '{print $1}')
export IMAGE_TAG=$(echo $IMAGE_FULL | awk -F':' '{print $3}')
export ECR_PATH=public.ecr.aws/powerscope/$IMAGE_NAME
```

> [!NOTE]
> Alias `x2l1o5j9` is the autogenerated repository alias for this public container registry, however, I manually requested `powerscope` in the AWS console so I can use it instead to reference this repository.


---

### Deploy

> [!WARNING]
> Do consider **[testing your image before deploying it](#test-it)** 

- Authenticate with AWS ...

```sh
aws ecr-public get-login-password --region us-east-1 | podman login --username AWS --password-stdin public.ecr.aws
```

- Deploy the image ...

```sh
podman tag $IMAGE_NAME:$IMAGE_TAG $ECR_PATH:$IMAGE_TAG
podman tag $IMAGE_NAME:$IMAGE_TAG $ECR_PATH:'latest'
podman push $ECR_PATH:$IMAGE_TAG
podman push $ECR_PATH:'latest'
```


---

### Test it

#### Run a shell in the image

- Run ...

```sh
podman run -t --rm -i $IMAGE_NAME:$IMAGE_TAG bash
```

#### Fetch a package from `<nixpkgs>`

- Run ...


```sh
podman run -t --rm -i $IMAGE_NAME:$IMAGE_TAG nix run nixpkgs#hello
```

#### Run a nix flake application

- Run ...

```sh
podman run -t --rm -v .:/builder -w /builder -i $IMAGE_NAME:$IMAGE_TAG nix run .#hello
```

#### Fetch a nix flake from `GitHub` and run it

- Create a personal access token
- Copy `.env.example` to `.env`
- Fill in `GITHUB_TOKEN`
- Run ...

```sh
podman run -t --rm -v .:/builder -w /builder -i $IMAGE_NAME:$IMAGE_TAG bash
source .env
nix run github:<org>/<repo>
```

> [!NOTE]
> `nix` relies on `NIX_CONFIG` (which specifies access tokens) to authenticate with `GitHub`

> [!NOTE]
> We can link our `nix flake` to a private repository like ...
> 
> ```nix
> {
>   inputs = {
>     private-repo = {
>       url = "github:<org>/<repo>";
>     };
>   # ...
> }
>
 
