{ nixpkgs ? import <nixpkgs> {} }:
with nixpkgs; buildGoPackage rec {
  name = "rmapi";
  version = "0.4-git";

  goPackagePath = "github.com/juruen/rmapi";

  src = fetchFromGitHub {
    owner = "juruen";
    repo = "rmapi";
    rev = "6e91f80";
    sha256 = "0k6b44dria54wg4mf5jkhx1h166hv5zbwkw0wq9pg4w50a5vsg2d";
  };

  goDeps = pkgs.writeText "rmapi-goDeps" # {{{
  ''[ { goPackagePath = "github.com/abiosoft/ishell";
        fetch = {
          type = "git";
          url = "https://github.com/abiosoft/ishell";
          rev = "v2.0.0";
          sha256 = "11r6l133aaz6khm60x0a410ckpzvqzv2az7z5b088c2vddnp538r";
        };
      }
      { goPackagePath = "github.com/chzyer/readline";
        fetch = {
          type = "git";
          url = "https://github.com/chzyer/readline";
          rev = "v1.4";
          sha256 = "1qd2qhjps26x4pin2614w732giy89p22b2qww4wg15zz5g2365nk";
        };
      }
      { goPackagePath = "github.com/fatih/color";
        fetch = {
          type = "git";
          url = "https://github.com/fatih/color";
          rev = "v1.7.0";
          sha256 = "0v8msvg38r8d1iiq2i5r4xyfx0invhc941kjrsg5gzwvagv55inv";
        };
      }
      { goPackagePath = "github.com/flynn-archive/go-shlex";
        fetch = {
          type = "git";
          url = "https://github.com/flynn-archive/go-shlex";
          rev = "3f9db97f856818214da2e1057f8ad84803971cff";
          sha256 = "1j743lysygkpa2s2gii2xr32j7bxgc15zv4113b0q9jhn676ysia";
        };
      }
      { goPackagePath = "github.com/jung-kurt/gofpdf";
        fetch = {
          type = "git";
          url = "https://github.com/jung-kurt/gofpdf";
          rev = "v2.7.1";
          sha256 = "1ialf76blz0ywh4gaiwi1lzncwr6j4i5cq8fdpv1pp17rir8j8ga";
        };
      }
      { goPackagePath = "github.com/mattn/go-colorable";
        fetch = {
          type = "git";
          url = "https://github.com/mattn/go-colorable";
          rev = "v0.1.2";
          sha256 = "0512jm3wmzkkn7d99x9wflyqf48n5ri3npy1fqkq6l6adc5mni3n";
        };
      }
      { goPackagePath = "github.com/mattn/go-isatty";
        fetch = {
          type = "git";
          url = "https://github.com/mattn/go-isatty";
          rev = "v0.0.8";
          sha256 = "0rqfh1rj6f5wm8p2ky7inm8g10152p7w6n2cli17kf9gad797i8h";
        };
      }
      { goPackagePath = "github.com/satori/go.uuid";
        fetch = {
          type = "git";
          url = "https://github.com/satori/go.uuid";
          rev = "v1.2.0";
          sha256 = "1j4s5pfg2ldm35y8ls8jah4dya2grfnx2drb4jcbjsyrp4cm5yfb";
        };
      }
      { goPackagePath = "gopkg.in/yaml.v2";
        fetch = {
          type = "git";
          url = "https://gopkg.in/yaml.v2";
          rev = "v2.2.2";
          sha256 = "01wj12jzsdqlnidpyjssmj0r4yavlqy7dwrg7adqd8dicjc4ncsa";
        };
      }
      { goPackagePath = "github.com/juruen/rmapi";
        fetch = {
          type = "git";
          url = "https://github.com/juruen/rmapi";
          rev = "6e91f80";
          sha256 = "0k6b44dria54wg4mf5jkhx1h166hv5zbwkw0wq9pg4w50a5vsg2d";
        };
      }
    ]
    '';  # }}}

  meta = with lib; {
    description = "
    Go app that allows you to access your reMarkable tablet files through the Cloud API";
    homepage = https://github.com/juruen/rmapi;
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
