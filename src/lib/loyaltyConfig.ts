export type LoyaltyTier = "poa" | "poa_gold" | "poa_platinum" | "poa_black";

export interface TierConfig {
    id: LoyaltyTier;
    name: string;
    minPoints: number; // Annual points required
    maxPoints: number;
    multiplier: number; // Points multiplier for purchases
    color: string;
    benefits: string[];
}

// Tier configuration matches user request
export const LOYALTY_TIERS: Record<LoyaltyTier, TierConfig> = {
    poa: {
        id: "poa",
        name: "Poá",
        minPoints: 0,
        maxPoints: 999,
        multiplier: 1.0,
        color: "bg-stone-500", // Brownish/Taupe
        benefits: [
            "Acumule 1 ponto a cada R$ 1 gasto",
            "Acesso antecipado a promoções",
            "Presente de aniversário"
        ]
    },
    poa_gold: {
        id: "poa_gold",
        name: "Poá Gold",
        minPoints: 1000,
        maxPoints: 2999,
        multiplier: 1.1,
        color: "#C5A572", // Gold/Beige
        benefits: [
            "Todos os benefícios Poá",
            "Acumule 1.1 pontos a cada R$ 1 gasto",
            "Frete grátis em 1 pedido por mês",
            "Consultoria de estilo express"
        ]
    },
    poa_platinum: {
        id: "poa_platinum",
        name: "Poá Platinum",
        minPoints: 3000,
        maxPoints: 5999,
        multiplier: 1.2,
        color: "#E5E4E2", // Platinum
        benefits: [
            "Todos os benefícios Gold",
            "Acumule 1.2 pontos a cada R$ 1 gasto",
            "Frete grátis ilimitado",
            "Acesso a eventos exclusivos"
        ]
    },
    poa_black: {
        id: "poa_black",
        name: "Poá Black",
        minPoints: 6000,
        maxPoints: Infinity,
        multiplier: 1.3,
        color: "#000000", // Black
        benefits: [
            "Todos os benefícios Platinum",
            "Acumule 1.3 pontos a cada R$ 1 gasto",
            "Concierge pessoal",
            "Presentes exclusivos da marca"
        ]
    },
};

export const TIER_ORDER: LoyaltyTier[] = ["poa", "poa_gold", "poa_platinum", "poa_black"];

export function getTierFromPoints(points: number): TierConfig {
    if (points >= LOYALTY_TIERS.poa_black.minPoints) return LOYALTY_TIERS.poa_black;
    if (points >= LOYALTY_TIERS.poa_platinum.minPoints) return LOYALTY_TIERS.poa_platinum;
    if (points >= LOYALTY_TIERS.poa_gold.minPoints) return LOYALTY_TIERS.poa_gold;
    return LOYALTY_TIERS.poa;
}
