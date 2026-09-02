/**
 * Turns the `SObjectField` hops of an injection path into the relationship names
 * the JSON round-trip grafts under, validating each against the describe and
 * throwing a clear error that names the bad field.
 *
 * `SObjectField` tokens do not carry a relationship name directly (`Foo__c` ->
 * `Foo__r`, `WhatId` -> `What`), and a child subquery's name lives on the parent
 * side - both are resolved here.
 */
@IsTest
public class XFTY_InjectionPathResolver {

    /** The parent relationship name for a lookup - 'Account' for `Contact.AccountId`, 'Parent' for `Account.ParentId`. */
    public static String parentRelationshipName(SObjectField relationshipField) {
        Schema.DescribeFieldResult describe = relationshipField.getDescribe();
        if (describe.getType() != Schema.DisplayType.REFERENCE) {
            throw badHop(describe.getName() + ' is not a lookup or master-detail field - it cannot be an ancestor hop.');
        }
        String relationshipName = describe.getRelationshipName();
        if (String.isBlank(relationshipName)) {
            throw badHop(describe.getName() + ' has no relationship name to graft an ancestor under.');
        }
        return relationshipName;
    }

    /** The child relationship name for a lookup back to `parentType` - 'Contacts' for `Account` + `Contact.AccountId`. */
    public static String childRelationshipName(SObjectType parentType, SObjectField childLookupField) {
        for (Schema.ChildRelationship child : parentType.getDescribe().getChildRelationships()) {
            Boolean isTheOne = child.getField() == childLookupField
                    && String.isNotBlank(child.getRelationshipName());
            if (isTheOne) {
                return child.getRelationshipName();
            }
        }
        throw badHop(
                parentType.getDescribe().getName() + ' has no named child relationship for '
                        + childLookupField.getDescribe().getName() + ' - it cannot be an injected subquery.'
        );
    }

    private static XFTY_DummySObjectFtyProviderException badHop(String detail) {
        return new XFTY_DummySObjectFtyProviderException('Injection path: ' + detail);
    }
}
