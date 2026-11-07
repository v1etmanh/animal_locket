package com.animallocket.billing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Danh mục sản phẩm. {@code sku} trùng với product id đăng ký trên App Store / Google Play. */
@Entity
@Table(name = "products")
@Getter
@NoArgsConstructor
public class Product {
    public enum Type { SUBSCRIPTION, CONSUMABLE, PACK }

    @Id
    @Column(length = 60)
    private String sku;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 14)
    private Type type;
    /** SUBSCRIPTION: "PRO". CONSUMABLE: "BOOST" | "PRIORITY_INVITE". PACK: mã gói con vật ("SAFARI"). */
    @Column(nullable = false, length = 40)
    private String item;
    @Column(nullable = false)
    private int quantity;
    @Column(nullable = false)
    private boolean active;

    public Product(String sku, Type type, String item, int quantity, boolean active) {
        this.sku = sku;
        this.type = type;
        this.item = item;
        this.quantity = quantity;
        this.active = active;
    }
}
