/**
 * Wires a shared ancestor into a bundle: one record stands in for every child at
 * its field, resolved once per test, then repeated `quantity` times.
 */
@IsTest
public class XFTY_SharedRelationshipWiring {

    public static void wire(
            XFTY_GenerationContext context,
            XFTY_SharedRelationshipIntf shared,
            XFTY_DummySObjectBundle bundle,
            SObjectField field,
            Integer quantity
    ) {
        XFTY_SharedRelationshipWiring wiring = new XFTY_SharedRelationshipWiring(context, shared);
        wiring.into(bundle, field, quantity);
    }

    private final XFTY_GenerationContext context;
    private final XFTY_SharedRelationshipIntf shared;

    private XFTY_SharedRelationshipWiring(XFTY_GenerationContext context, XFTY_SharedRelationshipIntf shared) {
        this.context = context;
        this.shared = shared;
    }

    private void into(XFTY_DummySObjectBundle bundle, SObjectField field, Integer quantity) {
        this.assertNotBatchedInsert();
        SObject record = this.shared.resolveSharedRecord(this.context);
        this.assertSavedConsistently();
        List<SObject> children = this.repeated(record, quantity);
        bundle.put(field, children);
        this.placeResolvedBundle(bundle, field);
    }

    private void placeResolvedBundle(XFTY_DummySObjectBundle bundle, SObjectField field) {
        XFTY_DummySObjectBundle resolved = this.shared.getResolvedBundle();
        if (resolved == null) {
            return;
        }
        bundle.put(field, resolved);
    }

    private List<SObject> repeated(SObject record, Integer times) {
        List<SObject> records = new List<SObject>();
        for (Integer i = 0; i < times; i++) {
            records.add(record);
        }
        return records;
    }

    private void assertNotBatchedInsert() {
        if (!this.context.batchedInsertPending) {
            return;
        }
        String message = 'Shared ancestor "' + this.name() + '" is not supported together with .depthBatched() or the '
                + 'DEFERRED insert mode - reference it from a Provider call using NOW / MOCK / NEVER.';
        throw new XFTY_DummySObjectFtyProviderException(message);
    }

    private void assertSavedConsistently() {
        Boolean runsInNowMode = XFTY_InsertModeEnum.NOW.equals(this.context.insertMode);
        Boolean recordUnsaved = !this.shared.isResolvedRecordPersisted();
        Boolean carriesAPhantomId = runsInNowMode && recordUnsaved;
        if (!carriesAPhantomId) {
            return;
        }
        String message = 'Shared ancestor "' + this.name() + '" was resolved without being inserted, but this NOW run '
                + 'would carry its Id onto inserted records. Use a consistent insert mode across the test, or register '
                + 'a saved record with XFTY_SharedAncestor.put("' + this.name() + '", record).';
        throw new XFTY_DummySObjectFtyProviderException(message);
    }

    private String name() {
        return this.shared.getSharedName();
    }
}
