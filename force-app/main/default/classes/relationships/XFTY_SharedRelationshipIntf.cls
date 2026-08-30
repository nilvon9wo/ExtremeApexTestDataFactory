/**
 * A relationship whose parent record is **shared** - every child that references
 * it gets the same record (and the same Id), and it is generated at most once per
 * test method.
 *
 * Extends `XFTY_DummyDefaultRelationshipIntf` so it drops into `putRequired(...)`
 * / `putOptional(...)` like any relationship. The factory branches on this
 * interface: instead of generating one parent per child it resolves the shared
 * record once and points every child at it.
 *
 * See docs/design/shared-ancestors.md.
 */
//@IsTest
public interface XFTY_SharedRelationshipIntf extends XFTY_DummyDefaultRelationshipIntf {
    /** The name this shared record is interned under. */
    String getSharedName();

    /**
     * The one shared record - generated (and cached) on first call, reused after.
     * Uses `context` for the Provider Lookup and the insert mode.
     */
    SObject resolveSharedRecord(XFTY_GenerationContext context);
}
