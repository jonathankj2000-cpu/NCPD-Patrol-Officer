Bean Bagger blue pump review — 2026-11-20

The player reports that the pistol grip is blue but the pump fore-end has its
stock colour since switching to the refactor branch. No new runtime diagnostics,
appearance override or material change is added for this report.

Verified facts

- The shipped Bean Bagger archive is byte-identical to the original v0.16b blue
  grip release (commit c0b7f5f8903a2ab5b1aa9b82d67589112fd5f1dd).
  SHA256: 30f5e6ac997f96bda63a1d5c5a1ea2a36ec5d796abfe0d4485cc4bba1ed3690e.
- Its authored appearance and both private meshes are also unchanged. The
  refactor branch did not revert the pump mesh to the stock resource.
- The appearance binds the main skinned Tactician component to the private
  `base/ncpd_patrol/beanbagger/pump.mesh`, and the grip component to `grip.mesh`.
- Both first- and third-person pump materials reference the private pump setup
  and their respective private masks. Layer 9 requests the private blue template
  and `ncpd_blue_28567d`; the masks contain nonzero coverage for this layer.
- The grip and pump share the same blue template. A working blue grip alone
  does not establish that the pump component, mask or later layers render as
  intended. Source and archive integrity checks cannot prove rendered colour.

Possible explanations, not established causes

- A separately installed appearance/weapon archive or tweak may override this
  item, factory or one of its private component resources. The installed load
  order and the complete mod directory are not available here.
- An existing item/entity may retain a different resolved appearance across an
  upgrade. A newly issued copy after a full restart can distinguish that case;
  the existing CET test-copy control is sufficient.
- A view-dependent mask/LOD path or higher material layers may cover the blue
  pump area. Both authored mask paths are present, but this requires a rendering
  comparison of the same item in first person and in the inventory/third person.

No clear source regression was identified. The archive stays unchanged rather
than applying an unverified recolour. Useful next comparisons are a fresh test
copy after restart and the previous complete v0.16b package under the same
installed mod set. Neither comparison requires new in-game diagnostic code.
