/**
 * Coverage for `XFTY_GenerationContext` - the constructor guards, the null
 * defaults, and the `forRelated()` recursion transforms.
 */
@IsTest
private class XFTY_GenerationContextTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    @IsTest
    static void constructorKeepsWhatItIsGiven() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL
        );

        Assert.areEqual(LOOKUP, context.providerLookup);
        Assert.areEqual(XFTY_InsertModeEnum.NOW, context.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, context.inclusivity);
    }

    @IsTest
    static void constructorRejectsANullProviderLookup() {
        try {
            new XFTY_GenerationContext(null, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);
            Assert.fail('Expected an exception');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('Provider Lookup'), ex.getMessage());
        }
    }

    @IsTest
    static void constructorDefaultsANullModeAndInclusivityToTheSafeValues() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(LOOKUP, null, null);

        Assert.areEqual(XFTY_InsertModeEnum.NEVER, context.insertMode, 'null mode defaults to NEVER');
        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, context.inclusivity, 'null inclusivity defaults to NONE');
    }

    @IsTest
    static void forRelatedTurnsRelatedOnlyIntoNow() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.RELATED_ONLY, XFTY_InsertInclusivityEnum.REQUIRED
        ).forRelated();

        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode, 'ancestors of a RELATED_ONLY run are inserted');
        Assert.areEqual(XFTY_InsertInclusivityEnum.REQUIRED, related.inclusivity, 'inclusivity is unchanged');
    }

    @IsTest
    static void forRelatedTurnsPreventCascadeIntoNone() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.PREVENT_CASCADE
        ).forRelated();

        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, related.inclusivity, 'the cascade stops one level down');
        Assert.areEqual(XFTY_InsertModeEnum.MOCK, related.insertMode, 'insert mode is unchanged');
    }

    @IsTest
    static void withForcedRelationshipPathsToleratesNull() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE
        ).withForcedRelationshipPaths(null);

        Assert.isNotNull(context.forcedRelationshipPaths);
        Assert.isTrue(context.forcedRelationshipPaths.isEmpty());
    }

    @IsTest
    static void batchedInsertPendingDefaultsFalseAndIsCarriedThroughEveryDerivation() {
        XFTY_GenerationContext base = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.ALL
        );
        Assert.isFalse(base.batchedInsertPending, 'a plain run is not a batched-insert run');

        XFTY_GenerationContext batched = base.forBatchedInsert();
        Assert.isTrue(batched.batchedInsertPending);
        Assert.isTrue(batched.withForcedRelationshipPaths(null).batchedInsertPending, 'carried through withForcedRelationshipPaths');
        Assert.isTrue(batched.forRelated().batchedInsertPending, 'carried down to ancestors');
        Assert.isTrue(
                batched.forRecord(new Account(), new XFTY_DummySObjectBundle(), 0).batchedInsertPending,
                'carried into the value pass'
        );
    }

    @IsTest
    static void baseContextHasNoPerRecordState() {
        XFTY_GenerationContext context = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE
        );

        Assert.isNull(context.recordBeingBuilt);
        Assert.isNull(context.bundleSoFar);
        Assert.areEqual(-1, context.rowIndex);
    }

    @IsTest
    static void forRecordScopesToOneRecordAndKeepsTheRun() {
        Account record = new Account(Name = 'ctx');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        XFTY_GenerationContext scoped = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.REQUIRED
        ).forRecord(record, bundle, 2);

        Assert.areEqual(record, scoped.recordBeingBuilt);
        Assert.areEqual(bundle, scoped.bundleSoFar);
        Assert.areEqual(2, scoped.rowIndex);
        Assert.areEqual(XFTY_InsertModeEnum.NOW, scoped.insertMode, 'the run settings are unchanged');
        Assert.areEqual(XFTY_InsertInclusivityEnum.REQUIRED, scoped.inclusivity);
        Assert.areEqual(LOOKUP, scoped.providerLookup);
    }

    @IsTest
    static void forValueFieldExposesASiblingAndGuardsAPendingOne() {
        Account record = new Account(Name = 'sib', Site = 'HQ');
        XFTY_GenerationContext atField = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE
        )
                .forRecord(record, new XFTY_DummySObjectBundle(), 0)
                .forValueField(Account.Description, new Set<SObjectField>{ Account.Type });

        Assert.areEqual('HQ', atField.siblingValue(Account.Site), 'a resolved sibling is readable');

        try {
            atField.siblingValue(Account.Type);
            Assert.fail('Expected an exception - Account.Type is still pending');
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            Assert.isTrue(ex.getMessage().contains('Type'), ex.getMessage());
            Assert.isTrue(ex.getMessage().contains('Description'), ex.getMessage());
        }
    }

    @IsTest
    static void forRelatedClearsAnyPerRecordState() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.ALL
        ).forRecord(new Account(), new XFTY_DummySObjectBundle(), 0).forRelated();

        Assert.isNull(related.recordBeingBuilt, 'descending into ancestors drops the current record');
        Assert.areEqual(-1, related.rowIndex);
    }

    @IsTest
    static void forRelatedCarriesEveryOtherModeAndInclusivityThrough() {
        XFTY_GenerationContext related = new XFTY_GenerationContext(
                LOOKUP, XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL
        ).forRelated();

        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, related.inclusivity);
        Assert.areEqual(LOOKUP, related.providerLookup, 'the Provider Lookup is always carried through');
    }
}
