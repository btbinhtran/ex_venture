defmodule Game.Command.MailTest do
  use ExVenture.CommandCase

  alias Game.Command.Mail

  doctest Mail

  setup do
    user = create_user(%{name: "user", password: "password"})
    character = create_character(user, %{name: "user"})

    %{state: session_state(%{user: user, character: character, save: character.save})}
  end

  describe "list out messages" do
    test "no messages", %{state: state} do
      :ok = Mail.run({:unread}, state)

      assert_socket_echo "no unread mail"
    end

    test "includes messages", %{state: state} do
      sender_user = create_user(%{name: "sender", password: "password"})
      sender = create_character(sender_user, %{name: "sender"})

      create_mail(sender, state.character, %{title: "hello"})

      {:paginate, mail, _state} = Mail.run({:unread}, state)

      assert Regex.match?(~r(hello), mail)
    end
  end

  describe "reading single mail items" do
    setup do
      sender_user = create_user(%{name: "sender", password: "password"})
      sender = create_character(sender_user, %{name: "sender"})
      %{sender: sender}
    end

    test "displays it and marks as read", %{sender: sender, state: state} do
      mail = create_mail(sender, state.character, %{title: "hello"})

      {:paginate, mail_text, _state} = Mail.run({:read, mail.id}, state)

      assert Regex.match?(~r(hello), mail_text)
      mail = Repo.get(Data.Mail, mail.id)
      assert mail.is_read
    end

    test "could not find mail", %{state: state} do
      :ok = Mail.run({:read, 10}, state)

      assert_socket_echo "could not"
    end

    test "trying to read someone else's mail", %{sender: sender, state: state} do
      other_user = create_user(%{name: "other", password: "password"})
      other_character = create_character(other_user, %{name: "other"})
      mail = create_mail(sender, other_character, %{title: "hello"})

      :ok = Mail.run({:read, mail.id}, state)

      assert_socket_echo "could not"
    end
  end

  describe "create new mail" do
    setup %{state: state} do
      receiver_user = create_user(%{name: "player", password: "password"})
      receiver = create_character(receiver_user, %{name: "player"})
      state = Map.put(state, :commands, %{})
      %{receiver: receiver, state: state}
    end

    test "starts a new editor", %{state: state, receiver: receiver} do
      {:editor, Mail, state} = Mail.run({:new, "player"}, state)

      assert state.commands.mail.player.id == receiver.id

      assert_socket_prompt "Title"
    end

    test "player not found", %{state: state} do
      :ok = Mail.run({:new, "unknown"}, state)

      assert_socket_echo "could not"
    end

    test "capture the title", %{state: state, receiver: receiver} do
      state = Map.put(state, :commands, %{mail: %{player: receiver, title: nil}})

      {:update, state} = Mail.editor({:text, "How are you?"}, state)

      assert state.commands.mail.title == "How are you?"
    end

    test "capture body lines", %{state: state, receiver: receiver} do
      state = Map.put(state, :commands, %{mail: %{player: receiver, title: "mail", body: []}})

      {:update, state} = Mail.editor({:text, "How are you?"}, state)

      assert state.commands.mail.body == ["How are you?"]
    end

    test "creates new mail", %{state: state, receiver: receiver} do
      state = Map.put(state, :commands, %{mail: %{player: receiver, title: "mail", body: ["Hi"]}})

      {:update, state} = Mail.editor(:complete, state)

      assert state.commands == %{}
      assert length(Game.Mail.unread_mail_for(receiver)) == 1
    end
  end
end
