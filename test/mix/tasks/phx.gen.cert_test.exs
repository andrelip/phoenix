Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.CertTest do
  use ExUnit.Case
  import MixHelper

  alias Mix.Tasks.Phx.Gen

  @otp_release :erlang.system_info(:otp_release) |> List.to_integer()

  if @otp_release >= 20 do
    # RSA key generation requires OTP 20 or later
    test "write certificate and key files" do
      in_tmp("mix_phx_gen_cert", fn ->
        Gen.Cert.run([])

        assert_received {:mix_shell, :info, ["* creating priv/cert/selfsigned_key.pem"]}
        assert_received {:mix_shell, :info, ["* creating priv/cert/selfsigned.pem"]}

        assert_file("priv/cert/selfsigned_key.pem", "-----BEGIN RSA PRIVATE KEY-----")
        assert_file("priv/cert/selfsigned.pem", "-----BEGIN CERTIFICATE-----")
      end)
    end

    test "write certificate and key with custom filename" do
      in_tmp("mix_phx_gen_cert", fn ->
        Gen.Cert.run(["-o", "priv/cert/localhost"])

        assert_received {:mix_shell, :info, ["* creating priv/cert/localhost_key.pem"]}
        assert_received {:mix_shell, :info, ["* creating priv/cert/localhost.pem"]}

        assert_file("priv/cert/localhost_key.pem", "-----BEGIN RSA PRIVATE KEY-----")
        assert_file("priv/cert/localhost.pem", "-----BEGIN CERTIFICATE-----")
      end)
    end

    test "TLS connection with generated certificate and key" do
      Application.ensure_all_started(:ssl)

      in_tmp("mix_phx_gen_cert", fn ->
        Gen.Cert.run([])

        assert {:ok, server} =
                 :ssl.listen(
                   0,
                   certfile: "priv/cert/selfsigned.pem",
                   keyfile: "priv/cert/selfsigned_key.pem"
                 )

        {:ok, {_, port}} = :ssl.sockname(server)

        spawn_link(fn ->
          with {:ok, conn} <- :ssl.transport_accept(server, 100),
               :ok <- :ssl.ssl_accept(conn, 200) do
            :ssl.close(conn)
          end
        end)

        # We don't actually verify the server cert contents, we just check that
        # the client and server are able to complete the TLS handshake
        assert {:ok, client} = :ssl.connect('localhost', port, [], 200)
        :ssl.close(client)
        :ssl.close(server)
      end)
    end
  end
end
