extends Node
class_name SystemHub

var context

func init(ctx):
    context = ctx

func on_card_played(card):
    if context.od_mode:
        context.od_mode.on_card_played(card)

    if context.combo_system:
        context.combo_system.on_card_played()

    if context.overload_system:
        context.overload_system.on_card_played(card)

    if context.keyword_system:
        context.keyword_system.on_card_played(card)