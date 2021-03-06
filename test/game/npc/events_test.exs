defmodule Game.NPC.EventsTest do
  use ExVenture.NPCCase

  import Test.DamageTypesHelper

  alias Data.Events.Actions.CommandsSay
  alias Data.Events.RoomHeard
  alias Data.Events.StateTicked
  alias Game.Channel
  alias Game.Message
  alias Game.NPC.Events
  alias Game.NPC.State

  setup do
    start_and_clear_damage_types()

    %{key: "slashing", stat_modifier: :strength, boost_ratio: 20}
    |> insert_damage_type()

    :ok
  end

  describe "calculating total delay for an event" do
    test "sums up all of the actions" do
      event = %RoomHeard{
        actions: [
          %CommandsSay{delay: 0.5},
          %CommandsSay{delay: 1.5}
        ]
      }

      assert Events.calculate_total_delay(event) == 2000
    end

    test "includes a random delay from the event itself" do
      event = %StateTicked{
        options: %{
          minimum_delay: 2.25,
          random_delay: 2,
        },
        actions: [
          %CommandsSay{delay: 0.5},
          %CommandsSay{delay: 1.5}
        ]
      }

      assert Events.calculate_total_delay(event) > 4250
    end
  end

  describe "character/died" do
    setup do
      npc = %{id: 1, name: "Mayor", events: [], stats: base_stats()}
      user = %{base_user() | id: 2}
      character = %{base_character(user) | id: 2}

      state = %State{room_id: 1, npc: npc, target: nil}

      start_room(%{npcs: [npc], players: [%{id: 1, name: "Player"}]})

      event = {"character/died", {:player, character}, :character, {:npc, npc}}

      %{state: state, event: event}
    end

    test "clears the target if they were targetting the character", %{state: state, event: event} do
      state = %{state | target: {:player, 2}}
      {:update, state} = Events.act_on(state, event)
      assert is_nil(state.target)
    end

    test "does nothing if the target does not match", %{state: state, event: event} do
      :ok = Events.act_on(state, event)
    end
  end

  describe "room/leave" do
    test "clears the target when player leaves" do
      npc = %{id: 1, name: "Mayor", events: []}
      state = %State{room_id: 1, npc: npc, target: {:player, 2}, combat: true}

      {:update, state} = Events.act_on(state, {"room/leave", {{:player, %{id: 2, name: "Player"}}, :leave}})

      assert is_nil(state.target)
      assert state.combat
    end

    test "does not touch the target if another player leaves" do
      npc = %{id: 1, name: "Mayor", events: []}
      state = %State{room_id: 1, npc: npc, target: {:player, 2}}

      :ok = Events.act_on(state, {"room/leave", {{:player, %{id: 3, name: "Player"}}, :leave}})
    end
  end

  describe "quest/completed" do
    setup do
      user = create_user()
      character = Data.Character.from_user(user)
      quest = %{id: 1, completed_message: "Hello"}
      npc = %{id: 1, name: "Mayor", events: [], stats: base_stats()}
      state = %State{room_id: 1, npc: npc, npc_spawner: %{room_id: 1}}
      event = {"quest/completed", user, quest}

      Channel.join_tell({:player, character})

      %{state: state, event: event}
    end

    test "sends a tell to the user with the after message", %{state: state, event: event} do
      :ok = Events.act_on(state, event)

      assert_receive {:channel, {:tell, {:npc, _}, %Message{message: "Hello"}}}
    end
  end
end
