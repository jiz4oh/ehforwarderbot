import pathlib
import shelve
import atexit
import uuid
from collections.abc import Mapping
from threading import Timer
from typing import Optional, Union, Dict
from typing_extensions import overload, Literal

from ruamel.yaml import YAML

from ehforwarderbot import Middleware, Message, Status, coordinator, utils
from ehforwarderbot.chat import Chat, SystemChat
from ehforwarderbot.types import ModuleID, MessageID, InstanceID, ChatID
from ehforwarderbot.message import MsgType, MessageCommands, MessageCommand
from ehforwarderbot.status import MessageRemoval, ReactToMessage, MessageReactionsUpdate


class FilterMiddleware(Middleware):
    """
    Filter middleware. 
    A demo of advanced user interaction with master channel.
    """
    middleware_id: ModuleID = ModuleID("filter.FilterMiddleware")
    middleware_name: str = "Filter Middleware"
    __version__: str = '1.1.1'

    message_cache: Dict[MessageID, Message] = {}

    def __init__(self, instance_id: Optional[InstanceID] = None):
        super().__init__(instance_id)

        # load config
        self.yaml = YAML()
        conf_path = utils.get_config_path(self.middleware_id)
        if not conf_path.exists():
            conf_path.touch()
        self.config = self.yaml.load(conf_path)

        self.filters = [
            self.chat_id_based_filter
        ]

        # Mapping
        self.FILTER_MAPPING = {
            "chat_name_contains": self.chat_name_contains_filter,
            "chat_name_matches": self.chat_name_matches_filter,
            "message_contains": self.message_contains_filter,
            "ews_mp": self.ews_mp_filter
        }

        # Chat ID based filter init
        shelve_path = str(utils.get_data_path(self.middleware_id) / "chat_id_filter.db")
        self.chat_id_filter_db = shelve.open(shelve_path)
        atexit.register(self.atexit)

        # load other filters
        if isinstance(self.config, Mapping):
            for i in self.config.keys():
                f = self.FILTER_MAPPING.get(i)
                if f:
                    self.filters.append(f)

    def atexit(self):
        self.chat_id_filter_db.close()

    def process_message(self, message: Message) -> Optional[Message]:
        # Only collect the message when it's a text message match the
        # hotword "filter`"
        if message.type == MsgType.Text and message.text == "filter`" and \
                message.deliver_to != coordinator.master:
            reply = self.make_status_message(message)
            self.message_cache[reply.uid] = message
            coordinator.master.send_message(reply)

            return None

        # Do not filter messages from master channel
        if message.deliver_to != coordinator.master:
            return message

        # Try to filter all other messages.
        return self.filter(message)

    def make_status_message(self, msg_base: Message = None, mid: MessageID = None) -> Message:
        if mid is not None:
            msg = self.message_cache[mid]
        elif msg_base is not None:
            msg = msg_base
        else:
            raise ValueError

        reply = Message(
            type=MsgType.Text,
            chat=msg.chat,
            author=msg.chat.make_system_member(uid=ChatID("filter_info"), name="Filter middleware", middleware=self),
            deliver_to=coordinator.master,
        )

        if mid:
            reply.uid = mid
        else:
            reply.uid = str(uuid.uuid4())

        status = self.filter_reason(msg)
        if not status:
            # Blue circle emoji
            status = "\U0001F535 This chat is not filtered."
        else:
            # Red circle emoji
            status = "\U0001F534 " + status

        reply.text = "Filter status for chat {chat_id} from {module_id}:\n" \
                     "\n" \
                     "{status}\n".format(
            module_id=msg.chat.module_id,
            chat_id=msg.chat.id,
            status=status
        )

        command = MessageCommand(
            name="%COMMAND_NAME%",
            callable_name="toggle_filter_by_chat_id",
            kwargs={
                "mid": reply.uid,
                "module_id": msg.chat.module_id,
                "chat_id": msg.chat.id
            }
        )

        if self.is_chat_filtered_by_id(msg.chat):
            command.name = "Unfilter by chat ID"
            command.kwargs['value'] = False
        else:
            command.name = "Filter by chat ID"
            command.kwargs['value'] = True
        reply.commands = MessageCommands([command])

        return reply

    def toggle_filter_by_chat_id(self, mid: str, module_id: str,
                                 chat_id: str, value: bool):
        self.chat_id_filter_db[str((module_id, chat_id))] = value
        reply = self.make_status_message(mid=mid)
        reply.edit = True
        # Timer(0.5, coordinator.master.send_message, args=(reply,)).start()
        coordinator.master.send_message(reply)

        return None

    @staticmethod
    def get_chat_key(chat: Chat) -> str:
        return str((chat.module_id, chat.id))

    def process_status(self, status: Status) -> Optional[Status]:
        for i in self.filters:
            if i(status, False):
                return None
        return status

    def filter_reason(self, message: Message):
        for i in self.filters:
            reason = i(message, True)
            if reason is not False:
                return reason
        return False

    def filter(self, message: Message):
        for i in self.filters:
            if i(message, False):
                return None
        return message

    @staticmethod
    def get_chat_from_entity(entity: Union[Message, Status]) -> Optional[Chat]:
        if isinstance(entity, Message):
            return entity.chat
        elif isinstance(entity, MessageRemoval):
            return entity.message.chat
        elif isinstance(entity, ReactToMessage):
            return entity.chat
        elif isinstance(entity, MessageReactionsUpdate):
            return entity.chat
        else:
            return None

    # region [Filters]

    """
    Filters
    
    Filter must take only two argument apart from self
    - ``entity`` (``Union[Message, Status]``)
        The message entity to filter
    - ``reason`` (``bool``)
        Determine whether or not to return the reason to block a message
    
    To allow a message to be delivered, return ``False``.
    
    Otherwise, return ``True`` or a string to explain the reason of filtering
    if ``reason`` is ``True``.
    """

    @overload
    def chat_id_based_filter(self,
                             entity: Union[Message, Status],
                             reason: Literal[True]) -> Union[bool, str]:
        ...

    @overload
    def chat_id_based_filter(self,
                             entity: Union[Message, Status],
                             reason: Literal[False]) -> bool:
        ...

    def chat_id_based_filter(self,
                             entity: Union[Message, Status],
                             reason: bool) -> Union[bool, str]:
        chat = self.get_chat_from_entity(entity)
        if not chat:
            return False
        if self.is_chat_filtered_by_id(chat):
            if reason:
                return "Chat is manually filtered."
            else:
                return True
        else:
            return False

    def is_chat_filtered_by_id(self, chat: Chat) -> bool:
        key = str((chat.module_id, chat.id))
        if key in self.chat_id_filter_db:
            return self.chat_id_filter_db[key]
        return False

    def chat_name_contains_filter(self, entity, reason):
        chat = self.get_chat_from_entity(entity)
        if not chat:
            return False
        for i in self.config['chat_name_contains']:
            if i in chat.display_name:
                if reason:
                    return "Chat is filtered because its name contains \"{}\".".format(i)
                else:
                    return True
        return False

    def chat_name_matches_filter(self, entity, reason):
        chat = self.get_chat_from_entity(entity)
        if not chat:
            return False
        for i in self.config['chat_name_matches']:
            if i == chat.display_name:
                if reason:
                    return "Chat is filtered because its name matches \"{}\".".format(i)
                else:
                    return True
        return False

    def message_contains_filter(self, entity, reason):
        if not isinstance(entity, Message):
            return False
        for i in self.config['message_contains']:
            if i in entity.text:
                if reason:
                    return "Message is filtered because its contains \"{}\".".format(i)
                else:
                    return True
        return False

    def ews_mp_filter(self, entity, reason):
        chat = self.get_chat_from_entity(entity)
        if not chat:
            return False
        if chat.vendor_specific.get('is_mp'):
            if reason:
                return "Chat is filtered as it's a EWS \"WeChat Official Account\" chat."
            else:
                return True
        return False

    # endregion [Filters]
