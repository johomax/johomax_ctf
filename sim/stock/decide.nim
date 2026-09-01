import stockbot
from stockprotocols import ProtocolClient

proc decide*(bot: Bot, client: ProtocolClient): uint8 =
  stockbot.decide(bot, client)
