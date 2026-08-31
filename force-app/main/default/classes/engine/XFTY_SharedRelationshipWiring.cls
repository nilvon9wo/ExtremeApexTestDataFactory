/**
 * Wires a shared ancestor into a bundle: one record stands in for every child at
 * its field, resolved once per test, then repeated `quantity` times.
 */
@IsTest
public class XFTY_SharedRelationshipWiring {

    private final XFTY_GenerationContext context;
    private final XFTY_SharedRelationshipIntf shared;

    public XFTY_SharedRelationshipWiring(
            XFTY_GenerationContext context,
            XFTY_SharedRelationshipIntf shared
    ) {
        this.context = context;
        this.shared = shared;
    }

    public void wire(XFTY_DummySObjectBundle bundle, SObjectField field, Integer quantity) {
        SObject record = this.shared.resolveSharedRecord(this.context);
        this.assertSavedConsistently();
        List<SObject> children = this.repeat(record, quantity);
        bundle.put(field, children);
        this.placeResolvedBundle(bundle, field);
    }

    private void assertSavedConsistently() {
        Boolean safe = XFTY_InsertModeEnum.NOW != this.context.insertMode
                || this.shared.isResolvedRecordPersisted();
        if (safe) {
            return;
        }
        String message =
                'Shared ancestor "' + this.name() + '" was resolved without being inserted, but this NOW run would '
                        + 'carry its Id onto inserted records. Use a consistent insert mode across the test, or register '
                        + 'a saved record with XFTY_SharedAncestor.put("' + this.name() + '", record).';
        throw new XFTY_DummySObjectFtyProviderException(message);
    }

    private List<SObject> repeat(SObject record, Integer times) {
        List<SObject> copies = new List<SObject>();
        for (Integer i = 0; i < times; i++) {
            copies.add(record);
        }
        return copies;
    }

    private void placeResolvedBundle(XFTY_DummySObjectBundle bundle, SObjectField field) {
        bundle.put(field, this.shared.getResolvedBundle());
    }

    private String name() {
        return this.shared.getSharedName();
    }
}
