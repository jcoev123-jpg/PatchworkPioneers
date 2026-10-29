content = open('tests/v3_scarecrow_pool_cards_test.gd').read()
replacements = [
    ('_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", 1, "unsupported_card")',
     '_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "unsupported_card", 1)'),
    ('_straw_wrap_refused(f, broken, 1, "unsupported_card")',
     '_straw_wrap_refused(f, broken, "unsupported_card", 1)'),
    ('_straw_wrap_refused(inactive, "scarecrow_straw_wrap", 1, "inactive_turn")',
     '_straw_wrap_refused(inactive, "scarecrow_straw_wrap", "inactive_turn", 1)'),
    ('_straw_wrap_refused(poor, "scarecrow_straw_wrap", 1, "insufficient_energy")',
     '_straw_wrap_refused(poor, "scarecrow_straw_wrap", "insufficient_energy", 1)'),
    ('_straw_wrap_refused(no_owner, "scarecrow_straw_wrap", 1, "owner_missing")',
     '_straw_wrap_refused(no_owner, "scarecrow_straw_wrap", "owner_missing", 1)'),
    ('_straw_wrap_refused(torn, "scarecrow_straw_wrap", 1, "owner_downed")',
     '_straw_wrap_refused(torn, "scarecrow_straw_wrap", "owner_downed", 1)'),
    ('_straw_wrap_refused(target_down, "scarecrow_straw_wrap", 1, "target_downed")',
     '_straw_wrap_refused(target_down, "scarecrow_straw_wrap", "target_downed", 1)'),
    ('_straw_wrap_refused(f, "scarecrow_straw_wrap", bad_target, "invalid_target")',
     '_straw_wrap_refused(f, "scarecrow_straw_wrap", "invalid_target", bad_target)'),
    ('_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", 2, "card_not_held")',
     '_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "card_not_held", 2)'),
    ('_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", 3, "card_not_held")',
     '_straw_wrap_refused(f, "scarecrow_straw_wrap_plus", "card_not_held", 3)'),
]
for old, new in replacements:
    content = content.replace(old, new)
open('tests/v3_scarecrow_pool_cards_test.gd', 'w').write(content)
print('Fixed all replacements')
