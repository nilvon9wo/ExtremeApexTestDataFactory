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
 * See docs/roadmap/shared-ancestors.md.
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

    /**
     * A single-record sub-bundle exposing the shared record, so `getBundle(field)`
     * and `getList(field)` on the parent bundle stay consistent. Never null once
     * the record is resolved.
     */
    XFTY_DummySObjectBundle getResolvedBundle();

    /** Whether the shared record has a real (inserted) Id - a `NOW` child needs this to be true. */
    Boolean isResolvedRecordPersisted();

    /** Whether the shared record has been generated yet (inline, or in the deep-ancestor pre-phase). */
    Boolean isResolved();
}
