#!/usr/bin/env bash
# Runs once as root on a clean Ubuntu 24.04.
# Installs Erlang/OTP 29.1.2 (official hex.pm bob build for ubuntu-24.04) and
# Elixir 1.20.4 (official precompiled build for OTP 29) -> /usr/local.
set -euo pipefail
OTP_VERSION=29.1.2
ELIXIR_VERSION=1.20.4

apt-get update -q
apt-get install -y -q curl ca-certificates unzip build-essential libssl3t64 libtinfo6 zlib1g

curl -fsSLo /tmp/otp.tar.gz "https://repo.hex.pm/builds/otp/ubuntu-24.04/OTP-${OTP_VERSION}.tar.gz"
rm -rf /usr/local/erlang && mkdir -p /usr/local/erlang
tar -C /usr/local/erlang -xzf /tmp/otp.tar.gz && rm /tmp/otp.tar.gz
/usr/local/erlang/bin/erl -noshell -eval 'io:format("OTP ~s~n", [erlang:system_info(otp_release)]), halt().'
for b in erl erlc epmd escript dialyzer; do ln -sf "/usr/local/erlang/bin/$b" "/usr/local/bin/$b"; done

curl -fsSLo /tmp/elixir.zip "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-29.zip"
rm -rf /usr/local/elixir && mkdir -p /usr/local/elixir
unzip -q /tmp/elixir.zip -d /usr/local/elixir && rm /tmp/elixir.zip
for b in elixir elixirc iex mix; do ln -sf "/usr/local/elixir/bin/$b" "/usr/local/bin/$b"; done
elixir --version
