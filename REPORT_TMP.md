@@CODER_STATUS_START@@
{"status":"COMPLETED"}
@@CODER_STATUS_END@@

Task: Spool Leech elite cloth-unpicking Drain bite (catalogued actor and existing enemy-phase receipt)
Branch: lane/deepseek-362-lane3-1793157041
Files changed:
- data/enemies/m04_elites.json
- tests/run_m04_elite_content_test.gd

Supporting changes (explained):
- Updated tests/run_m04_elite_content_test.gd _test_scissor_sting AC1 assertion to include spool_leech as a genuine chew_block_on_attack: true source, and excluded it from the "no fabricated trait" peer loop.
- Added unflagged Drain control in _leech_drain using a temporary record.duplicate(true).erase("chew_block_on_attack") to prove the phase still treats an unflagged source as ordinary drain.

No unrelated balance, concurrent lane edits, or art files changed. Full suite 427/427 passed.

@@ACCEPTANCE_CHECK_START@@
[{"criterion":"AC1","code":"data/enemies/m04_elites.json (added chew_block_on_attack: true to spool_leech) and KEYWORD_ELITES definition in tests/run_m04_elite_content_test.gd","verification":"run_m04_elite_content_test.gd exact catalog-by-ID checks (line 98-99, 1432-1445)","result":"PASS"},{"criterion":"AC2","code":"scripts/combat_enemy_phase.gd (existing _chews_block + _eat_block + drain resolution); tests updated in run_m04_elite_content_test.gd _leech_drain loop","verification":"run_m04_elite_content_test.gd forced attack-8 through CombatEnemyPhase.execute_phase for [12,0,10,8,8], [12,3,10,8,8], [12,8,10,8,8], [2,0,10,8,2], [12,0,3,3,3]; unflagged [12,8,10,0,0] control preserved separately","result":"PASS"},{"criterion":"AC3","code":"scripts/combat_enemy_phase.gd _attack_metadata_valid rejects non-bool; _eat_block only for living source; tests preserve fail-closed coverage in run_m04_elite_content_test.gd","verification":"run_m04_elite_content_test.gd malformed-metadata rejection (line 1607-1636), invalid announcement no-speculative-eat (line 1638-1652), unflagged drain zero-heal regression (line 2599-2624), plus combat_enemy_phase_test.gd and combat_enemy_keyword_rules_test.gd regressions all green","result":"PASS"}]
@@ACCEPTANCE_CHECK_END@@

Full-suite result: 427/427 passed (resumed from interrupted full run; 18 related tests re-verified green before resumption).
