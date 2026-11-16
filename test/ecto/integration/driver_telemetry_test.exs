defmodule Ecto.Integration.DriverTelemetryTest do
  use Ecto.Integration.Case
  import Ecto.Query

  alias Ecto.Integration.{Post, TestRepo}

  setup do
    handler_id = make_ref()

    :telemetry.attach_many(
      handler_id,
      [[:ch, :query, :start], [:ch, :query, :stop]],
      &__MODULE__.send_to_test/4,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  def send_to_test(event, _measurements, metadata, test) do
    if self() == test, do: send(test, {event, metadata})
  end

  test "a repo query emits the driver's query events in the calling process" do
    assert [] = TestRepo.all(from p in Post, where: p.title == ^"telemetry", select: p.id)

    assert_receive {[:ch, :query, :start],
                    %{query: %Ch.Query{command: :select, statement: statement}, source: "posts"}}

    assert IO.iodata_to_binary(statement) =~ ~s[FROM "posts"]
    assert_receive {[:ch, :query, :stop], %{error: nil}}
  end

  test "a repo insert emits the driver's query events" do
    TestRepo.insert!(%Post{title: "telemetry"})

    assert_receive {[:ch, :query, :stop],
                    %{query: %Ch.Query{command: :insert}, source: "posts", error: nil}}
  end

  test "a repo insert_all emits the driver's query events with its table" do
    TestRepo.insert_all(Post, [%{title: "telemetry"}])

    assert_receive {[:ch, :query, :stop],
                    %{query: %Ch.Query{command: :insert}, source: "posts", error: nil}}
  end

  test "a repo insert_stream emits the driver's query events with its table" do
    TestRepo.insert_stream(Post, [%{title: "telemetry"}])

    assert_receive {[:ch, :query, :start], %{query: %Ch.Query{command: :insert}, source: "posts"}}
  end
end
