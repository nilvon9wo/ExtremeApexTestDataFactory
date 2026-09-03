/**
 * Resolves the `field` passed to `bundle.inject(field, ...)` to the list of
 * records to enrich, the sub-bundle carrying their relationships, and whether
 * those records are a generated ancestor (so their inverse child can be grafted).
 * An unknown field is a loud error naming the fields the bundle actually holds.
 */
@IsTest
public class XFTY_EnrichmentTarget {

    public final List<SObject> records;
    public final XFTY_DummySObjectBundle subBundle;
    public final Boolean isGeneratedAncestor;

    private XFTY_EnrichmentTarget(
            List<SObject> records,
            XFTY_DummySObjectBundle subBundle,
            Boolean isGeneratedAncestor
    ) {
        this.records = records;
        this.subBundle = subBundle;
        this.isGeneratedAncestor = isGeneratedAncestor;
    }

    public static XFTY_EnrichmentTarget locate(XFTY_DummySObjectBundle bundle, SObjectField field) {
        if (field == bundle.primaryTargetField) {
            return new XFTY_EnrichmentTarget(bundle.primaryRecords(), bundle, false);
        }
        if (materialised(bundle.relationshipFields()).contains(field)) {
            return new XFTY_EnrichmentTarget(bundle.getList(field), bundle.getBundle(field), true);
        }
        if (materialised(bundle.childRelationshipFields()).contains(field)) {
            return new XFTY_EnrichmentTarget(bundle.getChildList(field), bundle.getChildBundle(field), false);
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: ' + field + ' is not this bundle\'s primary field, a generated ancestor field '
                        + bundle.relationshipFields() + ', or a child field ' + bundle.childRelationshipFields() + '.'
        );
    }

    /** True when the graph has any generated ancestor or child collection to inject. */
    public Boolean hasAnythingToInject() {
        Boolean hasParents = this.subBundle != null && !this.subBundle.relationshipFields().isEmpty();
        Boolean hasChildren = (this.subBundle != null && !this.subBundle.childRelationshipFields().isEmpty())
                || this.isGeneratedAncestor;
        return hasParents || hasChildren;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}
