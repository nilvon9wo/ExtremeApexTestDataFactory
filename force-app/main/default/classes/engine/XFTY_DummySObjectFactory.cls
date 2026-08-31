/**
 * Turns one master template plus the test's own partial templates into a wired
 * `XFTY_DummySObjectBundle`. `build` names the phases; each phase is its own class.
 */
@IsTest
public class XFTY_DummySObjectFactory {

    private final XFTY_GenerationContext context;
    private final XFTY_DummySObjectMasterTemplate template;

    private XFTY_DummySObjectFactory(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate
    ) {
        this.context = context;
        this.template = XFTY_RelationshipForcer.apply(context.forcedRelationshipPaths, masterTemplate);
    }

    public static XFTY_DummySObjectBundle createBundle(
            XFTY_GenerationContext context,
            XFTY_DummySObjectMasterTemplate masterTemplate,
            List<SObject> testTemplates
    ) {
        return new XFTY_DummySObjectFactory(context, masterTemplate)
                .build(testTemplates);
    }

    private XFTY_DummySObjectBundle build(List<SObject> testTemplates) {
        Integer quantity = testTemplates.size();
        XFTY_DummySObjectBundle bundle = new XFTY_AncestorGenerator(this.context, quantity, this.template)
                .generate();
        List<SObject> records = XFTY_PlainValueFiller.cloneAndCompletePlainValues(this.template, testTemplates);
        bundle.putPrimaries(this.template.primaryTargetField, records);
        new XFTY_LookupWiring(bundle, this.context, this.template)
                .wire();
        new XFTY_ContextAwareValuePass(bundle, this.context, this.template)
                .complete();
        this.persist(records);
        return bundle;
    }

    private void persist(List<SObject> records) {
        switch on this.context.insertMode {
            when NOW {
                insert records;
            }
            when MOCK {
                XFTY_IdMocker.addIds(records);
            }
        }
    }
}
