# assets/sprites/vfx

전투 이펙트용 실제 아트다.

| 파일 | 내용 |
|---|---|
| `pterosaur_queen_projectile.png` | 익룡 여왕 일반탄. 8x8 셀 x 3프레임 보라색 4각 별 회전 |
| `pterosaur_queen_projectile_frames.tres` | 일반탄 `spin` 애니메이션 (12fps) |
| `pterosaur_queen_projectile_charged.png` | 익룡 여왕 강화탄. 12x12 셀 x 3프레임 금색 6각 별·링 회전 |
| `pterosaur_queen_projectile_charged_frames.tres` | 강화탄 `spin` 애니메이션 (12fps) |

두 시트 모두 네이티브 픽셀 아트이며 `PterosaurQueenProjectile.tscn`에서 nearest 필터와
4배 확대를 사용한다. 보이는 크기와 별개로 실제 명중 반경은 `EnemyData.projectile_hit_radius`
(16px)가 단일 출처다.
